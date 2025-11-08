// controllers/paymentController.js - FIXED UPI ID VALIDATION

import mongoose from "mongoose";
import Payment from "../models/Payment.js";
import Expense from "../models/Expense.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import qrcode from "qrcode";
import { success, error } from "../utils/response.js";
import { io } from "../server.js";

// ========== HELPER: VALIDATE UPI ID ==========
function isValidUpiId(upiId) {
  if (!upiId || typeof upiId !== "string") return false;

  // Trim whitespace
  const trimmed = upiId.trim();

  // Check if empty or placeholder
  if (trimmed === "" || trimmed === "N/A" || trimmed.toLowerCase() === "null") {
    return false;
  }

  // Check minimum length (UPI IDs are typically username@bank format, minimum ~7 chars)
  if (trimmed.length < 7) return false;

  // Check for @ symbol (all UPI IDs must have this)
  if (!trimmed.includes("@")) return false;

  // Basic format validation: something@something
  const parts = trimmed.split("@");
  if (parts.length !== 2 || parts[0].length === 0 || parts[1].length === 0) {
    return false;
  }

  return true;
}

// ========== 1) CREATE PAYMENT (Splitwise or Friendwise) ==========
export const createPayment = async (req, res, next) => {
  try {
    const payerId = req.user.id;
    const { payeeId, expenseId, amount, method, source } = req.body;

    console.log("📤 [PAYMENT] Creating payment...");
    console.log("📋 [PAYMENT-BODY]", {
      payerId,
      payeeId,
      expenseId,
      amount,
      method,
      source,
    });

    // ========== VALIDATION ==========
    if (!payerId || !payeeId) {
      return error(res, 400, "Payer and payee IDs are required");
    }

    if (payerId === payeeId) {
      return error(res, 400, "You cannot pay yourself");
    }

    if (!["upi", "cash"].includes(method)) {
      return error(res, 400, 'Method must be "upi" or "cash"');
    }

    // ========== FETCH PAYEE ==========
    const payee = await User.findById(payeeId);
    if (!payee) {
      console.log("❌ Payee not found:", payeeId);
      return error(res, 404, "Payee not found");
    }

    // ========== CHECK UPI ID FOR UPI PAYMENTS (IMPROVED VALIDATION) ==========
    if (method === "upi") {
      const upiValid = isValidUpiId(payee.upiId);

      if (!upiValid) {
        console.log("❌ Payee has invalid or missing UPI ID:", payee.upiId);
        // Return clear error message
        return error(
          res,
          400,
          `To make the payment, ${payee.name} must first set up their UPI ID in their profile.`
        );
      }

      console.log("✅ Payee UPI ID validated:", payee.upiId);
    }

    // ========== DETERMINE PAYMENT AMOUNT & TYPE ==========
    let finalAmount = amount;
    let title = "Payment";
    let relatedExpenses = [];
    let paymentSource = source || "splitwise";

    // CASE 1: SPLITWISE (Single Expense)
    if (expenseId) {
      console.log("💰 [SPLITWISE] Looking for expense:", expenseId);
      const expense = await Expense.findById(expenseId).populate(
        "paidBy",
        "name upiId"
      );

      if (!expense) {
        console.log("❌ Expense not found:", expenseId);
        return error(res, 404, "Expense not found");
      }

      console.log("✅ Expense found:", expense._id);

      // Verify payee is the one who paid the expense
      if (expense.paidBy._id.toString() !== payeeId) {
        console.log("❌ Payee mismatch");
        return error(
          res,
          400,
          "Payee mismatch: This payee didn't pay this expense"
        );
      }

      const share = expense.splitDetails.find(
        (d) => d.user.toString() === payerId && d.status !== "paid"
      );

      if (!share) {
        console.log("❌ No unpaid share found for this user");
        return error(res, 400, "No unpaid share found for this expense");
      }

      finalAmount = share.finalShare;
      title = `${expense.description} - Expense Settlement`;
      relatedExpenses = [expenseId];
      paymentSource = "splitwise";

      console.log("✅ Expense share found:", finalAmount);
    }
    // CASE 2: FRIENDWISE (Clear All Debt)
    else if (!expenseId && !amount) {
      console.log("👥 [FRIENDWISE] Fetching all pending shared expenses...");

      // Find all expenses where this payer owes the payee
      const expenses = await Expense.find({
        paidBy: payeeId,
        "splitDetails.user": payerId,
        "splitDetails.status": "pending",
      })
        .select("description amount splitDetails paidBy")
        .lean();

      console.log(`📊 Found ${expenses.length} expenses between users.`);

      let total = 0;
      const pendingExpenseIds = [];

      for (const exp of expenses) {
        const share = exp.splitDetails.find(
          (s) => s.user.toString() === payerId && s.status === "pending"
        );
        if (share) {
          total += share.finalShare;
          pendingExpenseIds.push(exp._id);
        }
      }

      if (pendingExpenseIds.length === 0 || total === 0) {
        console.log("⚠️ No pending expenses found between users.");
        return error(res, 400, "No outstanding debt to this payee");
      }
      const alreadyLinked = await Payment.findOne({
        payer: payerId,
        payee: payeeId,
        relatedExpenses: { $in: pendingExpenseIds },
        status: { $in: ["created", "pending"] },
      });

      if (alreadyLinked) {
        return error(
          res,
          400,
          "There’s already a pending payment linked to these expenses."
        );
      }

      finalAmount = total;
      title = `Clear All Pending Debts with ${payee.name}`;
      relatedExpenses = pendingExpenseIds; // ✅ Attach all expense IDs here
      paymentSource = "friendwise";

      console.log(
        `✅ Friendwise payment ready: ${pendingExpenseIds.length} expenses, ₹${finalAmount}`
      );
    }

    // CASE 3: CUSTOM AMOUNT (Friendwise with specific amount)
    else if (!expenseId && amount) {
      console.log("💵 [FRIENDWISE] with custom amount:", amount);
      if (amount <= 0) {
        return error(res, 400, "Payment amount must be greater than 0");
      }
      finalAmount = amount;
      title = `Payment to ${payee.name}`;
      paymentSource = "friendwise";
    }

    if (!finalAmount || finalAmount <= 0) {
      console.log("❌ Invalid amount:", finalAmount);
      return error(res, 400, "Payment amount must be greater than 0");
    }

    console.log("💰 Final amount:", finalAmount);

    // ========== BUILD UPI DETAILS (ONLY IF METHOD IS UPI) ==========
    let upiIntent = null;
    let qrData = null;

    if (method === "upi") {
      const note = `PerSplit - ${title}`;
      upiIntent = `upi://pay?pa=${payee.upiId}&pn=${encodeURIComponent(
        payee.name
      )}&am=${finalAmount}&cu=INR&tn=${encodeURIComponent(note)}`;

      console.log("🔗 UPI Intent created");

      try {
        qrData = await qrcode.toDataURL(upiIntent);
        console.log("📱 QR Code generated");
      } catch (qrErr) {
        console.error("❌ QR Code generation failed:", qrErr.message);
      }
    } else {
      // For cash payments
      upiIntent = "N/A";
      qrData = "N/A";
    }

    // ========== CREATE PAYMENT RECORD ==========
    const payment = new Payment({
      payer: payerId,
      payee: payeeId,
      amount: finalAmount,
      method,
      upiIntent,
      qrData,
      note: `PerSplit - ${title}`,
      source: paymentSource,
      relatedExpenses,
      status: method === "upi" ? "created" : "pending",
    });

    const savedPayment = await payment.save();

    res.status(201).json({
      success: true,
      payment: savedPayment,
    });

    console.log("✅ Payment saved:", savedPayment._id);

    // ========== SEND NOTIFICATION ==========
    try {
      await Notification.create({
        user: payeeId,
        sender: payerId,
        type: "payment_request",
        message: `${req.user.name} initiated a payment of ₹${finalAmount}`,
        data: { paymentId: savedPayment._id },
      });
      console.log("🔔 Notification sent");
    } catch (notifErr) {
      console.error("❌ Notification creation error:", notifErr.message);
    }

    // Socket.io notification
    if (io) {
      io.to(payeeId.toString()).emit("payment_notification", {
        type: "payment_initiated",
        paymentId: savedPayment._id,
        amount: finalAmount,
        payer: req.user.name,
      });
    }

    console.log("✅ Payment created successfully");
    return success(res, 201, {
      message: `Payment created successfully via ${method}`,
      payment: savedPayment,
    });
  } catch (err) {
    console.error("❌ Payment creation error:", err);
    return error(res, 500, err.message || "Failed to create payment");
  }
};

// ========== 2) SUBMIT PAYMENT PROOF ==========
export const submitPaymentProof = async (req, res, next) => {
  try {
    const { paymentId } = req.params;
    const { transactionId } = req.body;
    const payerId = req.user.id;

    // 🔹 Validate payment exists
    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return error(res, 404, "Payment not found");
    }

    // 🔹 Authorization check
    if (payment.payer.toString() !== payerId) {
      return error(res, 403, "You are not authorized to update this payment");
    }

    // 🔹 Validate payment state
    if (payment.status !== "created" && payment.status !== "pending") {
      return error(
        res,
        400,
        `Cannot submit proof for payment with status: ${payment.status}`
      );
    }

    // 🔹 Optional proof logic
    // Only require transactionId for UPI payments
    if (payment.method === "upi" && !transactionId) {
      return error(res, 400, "Transaction ID is required for UPI payments");
    }

    // 🔹 Update payment
    if (transactionId) {
      payment.transactionId = transactionId.trim();
    } else if (payment.method === "cash") {
      payment.transactionId = "cash_paid";
    }

    payment.status = "pending";
    payment.updatedAt = new Date();
    await payment.save();

    // 🔹 Notify payee
    try {
      await Notification.create({
        user: payment.payee,
        sender: payerId,
        type: "payment_confirmed",
        message: `${req.user.name} has completed the payment of ₹${payment.amount}. Please verify.`,
        data: { paymentId: payment._id },
      });
    } catch (notifErr) {
      console.error("❌ Notification creation error:", notifErr);
    }

    // 🔹 Socket.io event
    if (io) {
      io.to(payment.payee.toString()).emit("payment_update", {
        type: "payment_pending_verification",
        paymentId: payment._id,
        amount: payment.amount,
        transactionId: payment.transactionId || null,
        payer: req.user.name,
      });
    }

    // 🔹 Success response
    return success(res, 200, {
      message: transactionId
        ? "Payment proof submitted. Awaiting payee confirmation."
        : "Payment marked as done. Awaiting payee confirmation.",
      payment,
    });
  } catch (err) {
    console.error("❌ Submit proof error:", err);
    return error(res, 500, err.message || "Failed to submit payment proof");
  }
};

// ========== 3) CONFIRM PAYMENT ==========
export const confirmPayment = async (req, res, next) => {
  try {
    const { paymentId } = req.params;
    const { verified, rejectionReason } = req.body;
    const payeeId = req.user.id;

    // FETCH PAYMENT
    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return error(res, 404, "Payment not found");
    }

    // AUTHORIZATION CHECK
    if (payment.payee.toString() !== payeeId) {
      return error(res, 403, "Only payee can confirm this payment");
    }

    // VALIDATE PAYMENT STATE
    if (payment.status !== "pending") {
      return error(
        res,
        400,
        `Cannot confirm payment with status: ${payment.status}`
      );
    }

    // UPDATE PAYMENT STATUS
    if (verified) {
      payment.status = "confirmed";
      payment.confirmedAt = new Date();

      // MARK RELATED EXPENSE SPLITS AS PAID
      if (payment.relatedExpenses && payment.relatedExpenses.length > 0) {
        try {
          for (const expenseId of payment.relatedExpenses) {
            const expense = await Expense.findById(expenseId);
            if (expense) {
              const splitIndex = expense.splitDetails.findIndex(
                (d) => d.user.toString() === payment.payer.toString()
              );
              if (splitIndex !== -1) {
                expense.splitDetails[splitIndex].status = "paid";
                await expense.save();
              }
            }
          }
        } catch (expErr) {
          console.error("❌ Error updating expense splits:", expErr);
        }
      }

      // NOTIFY PAYER - PAYMENT CONFIRMED
      try {
        await Notification.create({
          user: payment.payer,
          sender: payeeId,
          type: "payment_confirmed",
          message: `${req.user.name} confirmed your payment of ₹${payment.amount}`,
          data: { paymentId: payment._id },
        });
      } catch (notifErr) {
        console.error("❌ Notification creation error:", notifErr);
      }

      // Socket.io notification
      if (io) {
        io.to(payment.payer.toString()).emit("payment_update", {
          type: "payment_confirmed",
          paymentId: payment._id,
          amount: payment.amount,
          payee: req.user.name,
        });
      }
    } else {
      // REJECTED
      payment.status = "rejected";
      payment.rejectionReason =
        rejectionReason || "Payment verification failed";
      payment.confirmedAt = new Date();

      // NOTIFY PAYER - PAYMENT REJECTED
      try {
        await Notification.create({
          user: payment.payer,
          sender: payeeId,
          type: "payment_rejected",
          message: `${req.user.name} rejected your payment: ${
            rejectionReason || "No reason provided"
          }`,
          data: { paymentId: payment._id },
        });
      } catch (notifErr) {
        console.error("❌ Notification creation error:", notifErr);
      }

      // Socket.io notification
      if (io) {
        io.to(payment.payer.toString()).emit("payment_update", {
          type: "payment_rejected",
          paymentId: payment._id,
          reason: rejectionReason || "Payment verification failed",
          payee: req.user.name,
        });
      }
    }

    await payment.save();

    return success(res, 200, {
      message: `Payment ${verified ? "confirmed" : "rejected"}`,
      payment,
    });
  } catch (err) {
    console.error("❌ Confirm payment error:", err);
    return error(res, 500, err.message || "Failed to confirm payment");
  }
};

// ========== 4) GET PAYMENT STATUS ==========
export const getPaymentStatus = async (req, res, next) => {
  try {
    const { paymentId } = req.params;
    const userId = req.user.id;

    const payment = await Payment.findById(paymentId)
      .populate("payer", "name username email upiId")
      .populate("payee", "name username email upiId")
      .populate("relatedExpenses", "description amount");

    if (!payment) {
      return error(res, 404, "Payment not found");
    }

    // Only payer or payee can view
    if (
      payment.payer._id.toString() !== userId &&
      payment.payee._id.toString() !== userId
    ) {
      return error(res, 403, "Unauthorized");
    }

    return success(res, 200, { payment });
  } catch (err) {
    console.error("❌ Get payment status error:", err);
    return error(res, 500, err.message || "Failed to get payment status");
  }
};

// ========== 5) GET PENDING PAYMENTS (FOR PAYER) ==========
export const getPendingPaymentsToPay = async (req, res, next) => {
  try {
    const payerId = req.user.id;

    const payments = await Payment.find({
      payer: payerId,
      status: { $in: ["created", "pending"] },
    })
      .populate("payee", "name username email upiId")
      .populate("relatedExpenses", "description amount")
      .sort({ createdAt: -1 })
      .lean();

    return success(res, 200, { count: payments.length, payments });
  } catch (err) {
    console.error("❌ Get pending to-pay error:", err);
    return error(res, 500, err.message || "Failed to get pending payments");
  }
};

// ========== 6) GET PENDING PAYMENTS (FOR PAYEE) ==========
export const getPendingPaymentsToConfirm = async (req, res, next) => {
  try {
    const payeeId = req.user.id;

    const payments = await Payment.find({
      payee: payeeId,
      status: "pending",
    })
      .populate("payer", "name username email upiId")
      .populate("relatedExpenses", "description amount")
      .sort({ createdAt: -1 })
      .lean();

    return success(res, 200, { count: payments.length, payments });
  } catch (err) {
    console.error("❌ Get pending to-confirm error:", err);
    return error(res, 500, err.message || "Failed to get pending payments");
  }
};

// ========== 7) GET PAYMENT HISTORY ==========
export const getPaymentHistory = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { limit = 20, skip = 0, status } = req.query;

    const query = {
      $or: [{ payer: userId }, { payee: userId }],
    };

    if (status) {
      query.status = status;
    }

    const payments = await Payment.find(query)
      .populate("payer", "name username email")
      .populate("payee", "name username email")
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip))
      .lean();

    const total = await Payment.countDocuments(query);

    return success(res, 200, {
      total,
      count: payments.length,
      skip: parseInt(skip),
      limit: parseInt(limit),
      payments,
    });
  } catch (err) {
    console.error("❌ Get payment history error:", err);
    return error(res, 500, err.message || "Failed to get payment history");
  }
};

// ========== 8) GET PAYMENT STATS ==========
export const getPaymentStats = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Payments user has to make
    const toPayResult = await Payment.aggregate([
      {
        $match: {
          payer: new mongoose.Types.ObjectId(userId),
          status: { $in: ["created", "pending"] },
        },
      },
      {
        $group: {
          _id: null,
          total: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);

    // Payments pending from user to confirm
    const toConfirmResult = await Payment.aggregate([
      {
        $match: {
          payee: new mongoose.Types.ObjectId(userId),
          status: "pending",
        },
      },
      {
        $group: {
          _id: null,
          total: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);

    // Confirmed payments
    const confirmedResult = await Payment.aggregate([
      {
        $match: {
          $or: [
            { payer: new mongoose.Types.ObjectId(userId) },
            { payee: new mongoose.Types.ObjectId(userId) },
          ],
          status: "confirmed",
        },
      },
      {
        $group: {
          _id: null,
          total: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);

    return success(res, 200, {
      toPay: toPayResult[0] || { total: 0, count: 0 },
      toConfirm: toConfirmResult[0] || { total: 0, count: 0 },
      confirmed: confirmedResult[0] || { total: 0, count: 0 },
    });
  } catch (err) {
    console.error("❌ Get payment stats error:", err);
    return error(res, 500, err.message || "Failed to get payment stats");
  }
};

// ========== 9) CANCEL PAYMENT ==========
export const cancelPayment = async (req, res, next) => {
  try {
    const { paymentId } = req.params;
    const userId = req.user.id;

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return error(res, 404, "Payment not found");
    }

    // Only payer can cancel
    if (payment.payer.toString() !== userId) {
      return error(res, 403, "Only payer can cancel payment");
    }

    // Can only cancel if not confirmed or rejected
    if (payment.status === "confirmed" || payment.status === "rejected") {
      return error(
        res,
        400,
        `Cannot cancel payment with status: ${payment.status}`
      );
    }

    payment.status = "rejected";
    payment.rejectionReason = "Cancelled by payer";
    await payment.save();

    // Notify payee
    try {
      await Notification.create({
        user: payment.payee,
        sender: userId,
        type: "payment_cancelled",
        message: "A payment was cancelled",
        data: { paymentId: payment._id },
      });
    } catch (notifErr) {
      console.error("❌ Notification creation error:", notifErr);
    }

    // Socket.io notification
    if (io) {
      io.to(payment.payee.toString()).emit("payment_update", {
        type: "payment_cancelled",
        paymentId: payment._id,
        payer: req.user.name,
      });
    }

    return success(res, 200, { message: "Payment cancelled", payment });
  } catch (err) {
    console.error("❌ Cancel payment error:", err);
    return error(res, 500, err.message || "Failed to cancel payment");
  }
};
