import Expense from "../models/Expense.js";
import {
  calculateSplits,
  computeNetBalances,
  computeSettlement,
} from "../utils/expenseUtils.js";
import { success, error } from "../utils/response.js";
import { sendNotification } from "../utils/notificationUtils.js";
import { io } from "../server.js";

// Add Expense
export const addExpense = async (req, res, next) => {
  try {
    const {
      description,
      amount,
      group,
      splitType,
      splitDetails,
      category,
      notes,
      currency,
    } = req.body;
    const paidBy = req.user.id;

    if (!description || !amount)
      return error(res, 400, "Missing required fields");

    let splitDetailsForDB = [];
    if (splitDetails && splitDetails.length > 0 && splitType !== "none") {
      let participants = [];

      if (splitType === "equal") {
        participants = splitDetails.map((p) =>
          typeof p === "string" ? p : p.user
        );
      } else if (splitType === "percentage") {
        participants = splitDetails.map((p) => ({
          user: p.user,
          percentage: Number(p.percentage),
        }));
      } else if (splitType === "custom") {
        participants = splitDetails.map((p) => ({
          user: p.user,
          amount: Number(p.amount),
        }));
      }

      const calculated = calculateSplits(
        Number(amount),
        splitType,
        participants
      );
      splitDetailsForDB = calculated.map((c, idx) => {
        const orig = splitDetails[idx] || {};
        return {
          user: c.user,
          percentage: c.percentage ?? orig.percentage ?? null,
          amount: c.amount ?? orig.amount ?? null,
          finalShare: Number(c.finalShare),
          status: c.user.toString() === paidBy.toString() ? "paid" : "pending",
        };
      });
    }

    const expense = new Expense({
      description,
      amount: Number(amount),
      paidBy,
      group: group || null,
      splitType: splitType || "none",
      splitDetails: splitDetailsForDB,
      category: category || "other",
      notes: notes || "",
      currency: currency || "INR",
    });

    await expense.save();

    // Send notifications to participants (excluding the payer)
    for (const sd of splitDetailsForDB) {
      if (sd.user.toString() !== paidBy) {
        await sendNotification(io, {
          userId: sd.user,
          senderId: paidBy,
          type: "expense_added",
          message: `${req.user.name} added an expense: ${description}`,
          data: { expenseId: expense._id },
        });
      }
    }

    await expense.populate([
      { path: "paidBy", select: "name username email" },
      { path: "splitDetails.user", select: "name username email" },
    ]);

    return success(res, 201, { message: "Expense created", expense });
  } catch (err) {
    next(err);
  }
};

// Get single expense settlement
export const getExpenseSettlement = async (req, res, next) => {
  try {
    const { expenseId } = req.params;
    const expense = await Expense.findById(expenseId)
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .lean();

    if (!expense) return error(res, 404, "Expense not found");

    // 🔒 Authorization check: ensure requesting user is part of this expense
    const isParticipant =
      expense.paidBy._id.toString() === req.user.id ||
      expense.splitDetails.some((s) => s.user._id.toString() === req.user.id);

    if (!isParticipant) {
      return error(res, 403, "Access denied");
    }

    // Only authorized participants reach here
    const balances = computeNetBalances(expense);
    const transfers = computeSettlement(balances);

    return success(res, 200, { expenseId, balances, transfers });
  } catch (err) {
    next(err);
  }
};

// Get all expenses of the logged-in user with filter + pagination + date range + quick filters
export const getAllExpenses = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const {
      type = "all",     // all | instant | group | personal
      page = 1,         
      limit = 10,       
      startDate,        // custom date range (optional)
      endDate,          
      quickFilter       // "thisWeek" | "thisMonth" | "lastMonth"
    } = req.query;

    const query = {
      $or: [
        { paidBy: userId },
        { "splitDetails.user": userId },
      ],
    };

    // Type filter
    if (type !== "all") {
      query.expenseType = type;
    }

    // Date filters
    let rangeStart = startDate ? new Date(startDate) : null;
    let rangeEnd = endDate ? new Date(endDate) : null;

    // Quick filters
    if (quickFilter) {
      const now = new Date();
      if (quickFilter === "thisWeek") {
        const firstDay = new Date(now);
        firstDay.setDate(now.getDate() - now.getDay()); // Sunday
        firstDay.setHours(0, 0, 0, 0);
        const lastDay = new Date(firstDay);
        lastDay.setDate(firstDay.getDate() + 6); // Saturday
        lastDay.setHours(23, 59, 59, 999);
        rangeStart = firstDay;
        rangeEnd = lastDay;
      } else if (quickFilter === "thisMonth") {
        const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
        const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        lastDay.setHours(23, 59, 59, 999);
        rangeStart = firstDay;
        rangeEnd = lastDay;
      } else if (quickFilter === "lastMonth") {
        const firstDay = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const lastDay = new Date(now.getFullYear(), now.getMonth(), 0);
        lastDay.setHours(23, 59, 59, 999);
        rangeStart = firstDay;
        rangeEnd = lastDay;
      }
    }

    // Apply date range filter
    if (rangeStart || rangeEnd) {
      query.createdAt = {};
      if (rangeStart) query.createdAt.$gte = rangeStart;
      if (rangeEnd) query.createdAt.$lte = rangeEnd;
    }

    const pageNum = Number(page) || 1;
    const limitNum = Number(limit) || 10;
    const skip = (pageNum - 1) * limitNum;

    // Fetch expenses
    const expenses = await Expense.find(query)
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    const total = await Expense.countDocuments(query);

    return success(res, 200, {
      expenses,
      total,
      page: pageNum,
      limit: limitNum,
      totalPages: Math.ceil(total / limitNum),
      appliedFilter: quickFilter || "custom",
    });
  } catch (err) {
    next(err);
  }
};

// ======================= DELETE EXPENSE (Any Type) =======================
export const deleteExpense = async (req, res, next) => {
  const session = await Expense.startSession();
  session.startTransaction();
  try {
    const { expenseId } = req.params;
    const userId = req.user.id;

    const expense = await Expense.findById(expenseId).session(session);
    if (!expense) {
      await session.abortTransaction();
      session.endSession();
      return error(res, 404, "Expense not found");
    }

    // 🔒 Authorization: only the payer can delete the expense
    if (expense.paidBy.toString() !== userId) {
      await session.abortTransaction();
      session.endSession();
      return error(res, 403, "You are not allowed to delete this expense");
    }

    // 🗑 Delete the expense itself
    await Expense.deleteOne({ _id: expenseId }).session(session);

    // 🗑 Optionally: also delete linked records (if you store payments/settlements separately)
    // await Payment.deleteMany({ expense: expenseId }).session(session);
    // await Settlement.deleteMany({ expense: expenseId }).session(session);

    await session.commitTransaction();
    session.endSession();

    return success(res, 200, { message: "Expense deleted successfully" });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    next(err);
  }
};

// ======================= GET ALL PENDING EXPENSES =======================
export const getPendingExpenses = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // 🔍 Optimized MongoDB query:
    // Find all expenses where the current user is in splitDetails with "pending" status.
    const pendingExpenses = await Expense.find({
      "splitDetails": {
        $elemMatch: { user: userId, status: "pending" }
      }
    })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 }) // newest first
      .lean();

    if (!pendingExpenses.length)
      return success(res, 200, { message: "No pending expenses", expenses: [] });

    return success(res, 200, { expenses: pendingExpenses });
  } catch (err) {
    next(err);
  }
};

// ======================= GET NET AMOUNT WITH A SPECIFIC USER =======================
export const getNetAmountWithUser = async (req, res, next) => {
  try {
    const userId = req.user.id; // logged-in user
    const { friendId } = req.params;

    // 1️⃣ Fetch shared expenses between these two users
    const expenses = await Expense.find({
      $or: [
        { paidBy: { $in: [userId, friendId] } },
        { "splitDetails.user": { $in: [userId, friendId] } },
      ],
    })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .lean();

    if (!expenses.length) {
      return success(res, 200, {
        message: "No shared expenses between these users",
        netAmount: 0,
        relatedExpenses: [],
      });
    }

    let netAmount = 0; // +ve → friend owes me, -ve → I owe friend
    const relatedPendingExpenses = [];

    // 2️⃣ Loop through all shared expenses
    for (const exp of expenses) {
      const payer = exp.paidBy._id.toString();

      // Skip invalid/personal expenses
      if (!exp.splitDetails || exp.splitDetails.length <= 1) continue;

      // Find user and friend participation
      const mySplit = exp.splitDetails.find(
        (s) => s.user._id.toString() === userId
      );
      const friendSplit = exp.splitDetails.find(
        (s) => s.user._id.toString() === friendId
      );
      if (!mySplit || !friendSplit) continue;

      // Case 1: I paid → friend owes me (if friend still pending)
      if (payer === userId && friendSplit.status === "pending") {
        netAmount += friendSplit.finalShare;

        relatedPendingExpenses.push({
          expenseId: exp._id,
          title: exp.title,
          totalAmount: exp.amount,
          paidBy: exp.paidBy,
          mySplit,
          friendSplit,
          direction: "receive", // friend owes me
        });
      }

      // Case 2: Friend paid → I owe them (if I am pending)
      else if (payer === friendId && mySplit.status === "pending") {
        netAmount -= mySplit.finalShare;

        relatedPendingExpenses.push({
          expenseId: exp._id,
          title: exp.title,
          totalAmount: exp.amount,
          paidBy: exp.paidBy,
          mySplit,
          friendSplit,
          direction: "owe", // I owe friend
        });
      }
    }

    // 3️⃣ Prepare response object
    return success(res, 200, {
      between: {
        me: userId,
        friend: friendId,
      },
      netAmount,
      relatedExpenses: relatedPendingExpenses,
      message:
        netAmount > 0
          ? `You will receive ₹${netAmount.toFixed(2)} from this user`
          : netAmount < 0
          ? `You owe ₹${Math.abs(netAmount).toFixed(2)} to this user`
          : "All settled up!",
    });
  } catch (err) {
    console.error("❌ getNetAmountWithUser error:", err);
    next(err);
  }
};


