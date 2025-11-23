import mongoose from "mongoose";
import Payment from "../models/Payment.js";
import Expense from "../models/Expense.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { success, error } from "../utils/response.js";
import { io } from "../server.js";

// ---------------------------------------------------------
// 1. GET PAYEE DETAILS (USED FOR UPI INTENT & QR)
// ---------------------------------------------------------
export const getPayeeDetails = async (req, res) => {
  try {
    const { payeeId } = req.params;
    const { amount } = req.query; // optional

    const payee = await User.findById(payeeId).select(
      "name upiId email username"
    );
    if (!payee) return error(res, 404, "Payee not found");

    if (!payee.upiId || payee.upiId.trim() === "")
      return error(res, 400, `${payee.name} has not set a valid UPI ID`);

    const note = `PerSplit - Payment to ${payee.name}`;

    const upiIntent =
      `upi://pay?pa=${payee.upiId}` +
      `&pn=${encodeURIComponent(payee.name)}` +
      (amount ? `&am=${amount}` : "") +
      `&cu=INR` +
      `&tn=${encodeURIComponent(note)}`;

    return success(res, 200, {
      payee: {
        id: payee._id,
        name: payee.name,
        username: payee.username,
        email: payee.email,
        upiId: payee.upiId,
      },
      upiIntent,
      note,
    });
  } catch (err) {
    return error(res, 500, err.message);
  }
};

// ---------------------------------------------------------
// 2. SUBMIT PAYMENT (AFTER REAL PAYMENT IS DONE)
// ---------------------------------------------------------
export const submitPayment = async (req, res) => {
  try {
    const payerId = req.user.id;
    const { payeeId, expenseId, amount, method, transactionId, note } =
      req.body;

    if (!payeeId) return error(res, 400, "Payee ID is required");
    if (!["upi", "cash"].includes(method))
      return error(res, 400, "Invalid payment method");

    if (!expenseId && !amount)
      return error(res, 400, "Either expenseId or amount is required");

    let finalAmount = amount;
    let relatedExpenses = [];
    let source = "friendwise";

    // ---------------------------------------------------------
    // CASE A: SPLITWISE => settle ONE expense
    // ---------------------------------------------------------
    if (expenseId) {
      const expense = await Expense.findById(expenseId);
      if (!expense) return error(res, 404, "Expense not found");

      if (expense.paidBy.toString() !== payeeId)
        return error(res, 400, "This payee did not pay for that expense");

      const split = expense.splitDetails.find(
        (s) => s.user.toString() === payerId && s.status !== "paid"
      );
      if (!split) return error(res, 400, "No pending share found");

      finalAmount = split.finalShare;
      relatedExpenses = [expenseId];
      source = "splitwise";
    }

    // ---------------------------------------------------------
    // CASE B: FRIENDWISE => settle ALL mutual pending expenses
    // ---------------------------------------------------------
    else {
      // Fetch all mutual pending expenses (both directions)
      const pendingExpenses = await Expense.find({
        $or: [
          // You owe friend
          {
            paidBy: payeeId,
            "splitDetails.user": payerId,
            "splitDetails.status": "pending",
          },
          // Friend owes you
          {
            paidBy: payerId,
            "splitDetails.user": payeeId,
            "splitDetails.status": "pending",
          },
        ],
      });

      let netTotal = 0;

      for (const exp of pendingExpenses) {
        let shareAmt = 0;

        // Case 1 — You owe friend → your split pending
        if (exp.paidBy.toString() === payeeId) {
          const mySplit = exp.splitDetails.find(
            (s) => s.user.toString() === payerId && s.status === "pending"
          );
          if (mySplit) shareAmt = mySplit.finalShare;
        }

        // Case 2 — Friend owes you → their split pending
        if (exp.paidBy.toString() === payerId) {
          const frSplit = exp.splitDetails.find(
            (s) => s.user.toString() === payeeId && s.status === "pending"
          );
          if (frSplit) shareAmt = -frSplit.finalShare;
        }

        if (shareAmt !== 0) {
          netTotal += shareAmt;
          relatedExpenses.push(exp._id);
        }
      }

      // If mutual expenses exist ⇒ use net total
      if (relatedExpenses.length > 0) {
        finalAmount = Math.abs(netTotal);
      }

      // If no shared expenses ⇒ custom Friendwise payment
      source = "friendwise";
    }

    if (finalAmount <= 0) return error(res, 400, "Invalid amount");

    // ---------------------------------------------------------
    // CREATE PAYMENT ENTRY
    // ---------------------------------------------------------
    const payment = await Payment.create({
      payer: payerId,
      payee: payeeId,
      amount: finalAmount,
      method,
      status: "pending",
      transactionId: transactionId || null,
      note: note || null,
      source,
      relatedExpenses,
    });

    // Set all related splits to "accepted" (awaiting confirmation)
    for (const expId of relatedExpenses) {
      const exp = await Expense.findById(expId);

      // Mark either user's pending split as "accepted"
      for (const s of exp.splitDetails) {
        if (["pending"].includes(s.status)) {
          if (s.user.toString() === payerId || s.user.toString() === payeeId) {
            s.status = "accepted";
          }
        }
      }

      await exp.save();
    }

    // Notify payee
    await Notification.create({
      user: payeeId,
      sender: payerId,
      type: "payment_request",
      message: `You have a new payment of ₹${finalAmount} awaiting verification`,
      data: { paymentId: payment._id },
    });

    return success(res, 201, {
      message: "Payment submitted. Awaiting payee confirmation.",
      payment,
    });
  } catch (err) {
    return error(res, 500, err.message);
  }
};

// ---------------------------------------------------------
// 3. PAYEE CONFIRM OR REJECT PAYMENT
// ---------------------------------------------------------
export const verifyPayment = async (req, res) => {
  try {
    const { paymentId } = req.params;
    const { verified, rejectionReason } = req.body;
    const payeeId = req.user.id;

    const payment = await Payment.findById(paymentId);
    if (!payment) return error(res, 404, "Payment not found");

    if (payment.payee.toString() !== payeeId)
      return error(res, 403, "Only payee can verify");

    if (payment.status !== "pending")
      return error(res, 400, "Payment already processed");

    // ---------------------------------------------------------
    // PAYMENT APPROVED
    // ---------------------------------------------------------
    if (verified) {
      payment.status = "confirmed";
      payment.confirmedAt = new Date();
      await payment.save();

      for (const expId of payment.relatedExpenses) {
        const exp = await Expense.findById(expId);

        // Mark BOTH users' split parts as PAID
        for (const s of exp.splitDetails) {
          if (s.status === "accepted") {
            s.status = "paid";
          }
        }

        await exp.save();
      }

      await Notification.create({
        user: payment.payer,
        sender: payeeId,
        type: "payment_confirmed",
        message: `Your payment of ₹${payment.amount} has been approved`,
        data: { paymentId },
      });

      return success(res, 200, {
        message: "Payment confirmed",
        payment,
      });
    }

    // ---------------------------------------------------------
    // PAYMENT REJECTED
    // ---------------------------------------------------------
    payment.status = "rejected";
    payment.rejectionReason = rejectionReason || "Rejected by payee";
    await payment.save();

    // Reset accepted splits → back to pending
    for (const expId of payment.relatedExpenses) {
      const exp = await Expense.findById(expId);
      for (const s of exp.splitDetails) {
        if (s.status === "accepted") {
          s.status = "pending";
        }
      }
      await exp.save();
    }

    await Notification.create({
      user: payment.payer,
      sender: payeeId,
      type: "payment_rejected",
      message: `Payment rejected: ${payment.rejectionReason}`,
      data: { paymentId },
    });

    return success(res, 200, {
      message: "Payment rejected",
      payment,
    });
  } catch (err) {
    return error(res, 500, err.message);
  }
};

// ---------------------------------------------------------
// 4. CANCEL PAYMENT (ONLY PAYER)
// ---------------------------------------------------------
export const cancelPayment = async (req, res) => {
  try {
    const { paymentId } = req.params;
    const payerId = req.user.id;

    const payment = await Payment.findById(paymentId);
    if (!payment) return error(res, 404, "Payment not found");

    if (payment.payer.toString() !== payerId)
      return error(res, 403, "Not allowed");

    if (payment.status !== "pending")
      return error(res, 400, "Cannot cancel processed payment");

    payment.status = "rejected";
    payment.rejectionReason = "Cancelled by payer";
    await payment.save();

    for (const expId of payment.relatedExpenses) {
      const exp = await Expense.findById(expId);
      const idx = exp.splitDetails.findIndex(
        (s) => s.user.toString() === payerId
      );
      if (idx !== -1) {
        exp.splitDetails[idx].status = "pending";
        await exp.save();
      }
    }

    return success(res, 200, {
      message: "Payment cancelled",
      payment,
    });
  } catch (err) {
    return error(res, 500, err.message);
  }
};

// ---------------------------------------------------------
// 5. GET PAYMENT STATUS
// ---------------------------------------------------------
export const getPaymentStatus = async (req, res) => {
  try {
    const { paymentId } = req.params;
    const userId = req.user.id;

    const payment = await Payment.findById(paymentId)
      .populate("payer", "name username")
      .populate("payee", "name username")
      .populate("relatedExpenses", "description amount");

    if (!payment) return error(res, 404, "Payment not found");

    if (
      payment.payer._id.toString() !== userId &&
      payment.payee._id.toString() !== userId
    ) {
      return error(res, 403, "Access denied");
    }

    return success(res, 200, { payment });
  } catch (err) {
    return error(res, 500, err.message);
  }
};

// ---------------------------------------------------------
// 6. GET PENDING PAYMENTS (TO PAY)
// ---------------------------------------------------------
export const getPendingPaymentsToPay = async (req, res) => {
  try {
    const payerId = req.user.id;

    const payments = await Payment.find({
      payer: payerId,
      status: "pending",
    })
      .populate("payee", "name username")
      .populate("relatedExpenses", "description amount")
      .sort({ createdAt: -1 });

    return success(res, 200, {
      count: payments.length,
      payments,
    });
  } catch (err) {
    return error(res, 500, err.message);
  }
};

// ---------------------------------------------------------
// 7. GET PENDING PAYMENTS (TO CONFIRM)
// ---------------------------------------------------------
export const getPendingPaymentsToConfirm = async (req, res) => {
  try {
    const payeeId = req.user.id;

    const payments = await Payment.find({
      payee: payeeId,
      status: "pending",
    })
      .populate("payer", "name username")
      .populate("relatedExpenses", "description amount")
      .sort({ createdAt: -1 });

    return success(res, 200, {
      count: payments.length,
      payments,
    });
  } catch (err) {
    return error(res, 500, err.message);
  }
};
