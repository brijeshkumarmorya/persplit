import Expense from "../models/Expense.js";
import User from "../models/User.js"; 
import {
  calculateSplits,
  computeNetBalances,
  computeSettlement,
} from "../utils/expenseUtils.js";
import { success, error } from "../utils/response.js";
import { sendNotification } from "../utils/notificationUtils.js";
import { io } from "../server.js";

/**
 * Add Expense - FULLY FIXED FOR ALL TYPES
 * ✅ Personal: No split, just saves expense
 * ✅ Group: All group members included
 * ✅ Instant: Current user + selected friends
 */
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
      type, // ✅ ADD THIS - personal | group | instant
    } = req.body;
    const paidBy = req.user.id;

    console.log("\n============ BACKEND: ADD EXPENSE ============");
    console.log("Description:", description);
    console.log("Amount:", amount);
    console.log("Type:", type); // ✅ NEW
    console.log("Split Type:", splitType);
    console.log("Paid By (from JWT):", paidBy);
    console.log("Group:", group);
    console.log(
      "Received splitDetails:",
      JSON.stringify(splitDetails, null, 2)
    );
    console.log("==============================================\n");

    // Validation
    if (!description || !amount)
      return error(res, 400, "Missing required fields");

    // ✅ DETERMINE EXPENSE TYPE
    let expenseType = type || "personal";
    if (group) expenseType = "group";
    if (!group && splitDetails && splitDetails.length > 0)
      expenseType = "instant";

    let splitDetailsForDB = [];

    // ✅ HANDLE DIFFERENT EXPENSE TYPES
    if (expenseType === "personal") {
      // Personal expense: No split needed
      console.log("📝 Personal Expense - No split");
      splitDetailsForDB = [];
    } else if (
      splitDetails &&
      splitDetails.length > 0 &&
      splitType !== "none"
    ) {
      let participants = [];

      // ✅ FOR INSTANT: Add current user to splitDetails
      if (expenseType === "instant") {
        console.log("⚡ INSTANT Split detected");

        // Check if current user already in splitDetails
        const currentUserExists = splitDetails.some(
          (p) => (p.user || p).toString() === paidBy.toString()
        );

        if (!currentUserExists) {
          console.log("✅ Adding current user to participants");

          // Calculate current user's share based on split type
          if (splitType === "equal") {
            const totalParticipants = splitDetails.length + 1;
            const userShare = amount / totalParticipants;

            splitDetails.unshift({
              user: paidBy,
              amount: userShare,
              percentage: 100 / totalParticipants,
            });
          } else if (splitType === "percentage") {
            // Calculate remaining percentage
            let totalPercentage = 0;
            splitDetails.forEach(
              (p) => (totalPercentage += Number(p.percentage || 0))
            );
            const remainingPercentage = 100 - totalPercentage;

            splitDetails.unshift({
              user: paidBy,
              percentage: remainingPercentage,
              amount: (amount * remainingPercentage) / 100,
            });
          } else if (splitType === "custom") {
            // Calculate remaining amount
            let totalAmount = 0;
            splitDetails.forEach((p) => (totalAmount += Number(p.amount || 0)));
            const remainingAmount = amount - totalAmount;

            splitDetails.unshift({
              user: paidBy,
              amount: remainingAmount,
              percentage: (remainingAmount / amount) * 100,
            });
          }
        }
      }

      // ✅ PROCESS PARTICIPANTS BASED ON SPLIT TYPE
      if (splitType === "equal") {
        participants = splitDetails.map((p) =>
          typeof p === "string" ? p : p.user
        );
        console.log("⚖️ Equal split participants:", participants);
      } else if (splitType === "percentage") {
        participants = splitDetails.map((p) => ({
          user: p.user,
          percentage: Number(p.percentage),
        }));
        console.log("📊 Percentage split participants:", participants);
      } else if (splitType === "custom") {
        participants = splitDetails.map((p) => ({
          user: p.user,
          amount: Number(p.amount),
        }));
        console.log("💰 Custom split participants:", participants);
      }

      // ✅ CALCULATE SPLITS
      const calculated = calculateSplits(
        Number(amount),
        splitType,
        participants
      );

      console.log("🧮 Calculated splits:", calculated);

      // ✅ CREATE SPLIT DETAILS FOR DATABASE
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

      console.log(
        "💾 Final splitDetailsForDB:",
        JSON.stringify(splitDetailsForDB, null, 2)
      );
    }

    // ✅ CREATE EXPENSE
    const expense = new Expense({
      description,
      amount: Number(amount),
      paidBy,
      group: group || null,
      expenseType, // ✅ SAVE EXPENSE TYPE
      splitType: splitType || "none",
      splitDetails: splitDetailsForDB,
      category: category || "other",
      notes: notes || "",
      currency: currency || "INR",
    });

    await expense.save();
    console.log("✅ Expense saved to database");

    // ✅ SEND NOTIFICATIONS (except to payer)

    for (const sd of splitDetailsForDB) {
      if (sd.user.toString() !== paidBy.toString()) {
        // Fetch sender name ONLY once per loop
        const sender = await User.findById(paidBy).select("name");

        await sendNotification(io, {
          userId: sd.user, // who should receive notification
          senderId: paidBy, // who created/paid expense
          type: "expense_added",
          message: `${
            sender?.name || "Someone"
          } added an expense: ${description}`,
          data: { expenseId: expense._id },
        });
      }
    }

    await expense.populate([
      { path: "paidBy", select: "name username email" },
      { path: "splitDetails.user", select: "name username email" },
    ]);

    console.log("✅ SUCCESS - Expense created with type:", expenseType);
    console.log("==============================================\n");

    return success(res, 201, { message: "Expense created", expense });
  } catch (err) {
    console.error("❌ ERROR in addExpense:", err);
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

    // 🔒 Authorization check
    const isParticipant =
      expense.paidBy._id.toString() === req.user.id ||
      expense.splitDetails.some((s) => s.user._id.toString() === req.user.id);

    if (!isParticipant) {
      return error(res, 403, "Access denied");
    }

    const balances = computeNetBalances(expense);
    const transfers = computeSettlement(balances);

    return success(res, 200, { expenseId, balances, transfers });
  } catch (err) {
    next(err);
  }
};

// Get all expenses (FIXED to use expenseType field)
export const getAllExpenses = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const {
      type = "all",
      page = 1,
      limit = 10,
      startDate,
      endDate,
      quickFilter,
    } = req.query;

    const query = {
      $or: [{ paidBy: userId }, { "splitDetails.user": userId }],
    };

    // ✅ FIXED: Use expenseType field
    if (type !== "all") {
      query.expenseType = type;
    }

    // Date filters
    let rangeStart = startDate ? new Date(startDate) : null;
    let rangeEnd = endDate ? new Date(endDate) : null;

    if (quickFilter) {
      const now = new Date();
      if (quickFilter === "thisWeek") {
        const firstDay = new Date(now);
        firstDay.setDate(now.getDate() - now.getDay());
        firstDay.setHours(0, 0, 0, 0);
        const lastDay = new Date(firstDay);
        lastDay.setDate(firstDay.getDate() + 6);
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

    if (rangeStart || rangeEnd) {
      query.createdAt = {};
      if (rangeStart) query.createdAt.$gte = rangeStart;
      if (rangeEnd) query.createdAt.$lte = rangeEnd;
    }

    const pageNum = Number(page) || 1;
    const limitNum = Number(limit) || 10;
    const skip = (pageNum - 1) * limitNum;

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

    if (expense.paidBy.toString() !== userId) {
      await session.abortTransaction();
      session.endSession();
      return error(res, 403, "You are not allowed to delete this expense");
    }

    await Expense.deleteOne({ _id: expenseId }).session(session);

    await session.commitTransaction();
    session.endSession();

    return success(res, 200, { message: "Expense deleted successfully" });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    next(err);
  }
};

export const getPendingExpenses = async (req, res, next) => {
  try {
    const userId = req.user.id;

    const pendingExpenses = await Expense.find({
      splitDetails: {
        $elemMatch: { user: userId, status: "pending" },
      },
    })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 })
      .lean();

    if (!pendingExpenses.length)
      return success(res, 200, {
        message: "No pending expenses",
        expenses: [],
      });

    return success(res, 200, { expenses: pendingExpenses });
  } catch (err) {
    next(err);
  }
};

export const getNetAmountWithUser = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { friendId } = req.params;

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

    let netAmount = 0;
    const relatedPendingExpenses = [];

    for (const exp of expenses) {
      const payer = exp.paidBy._id.toString();

      if (!exp.splitDetails || exp.splitDetails.length <= 1) continue;

      const mySplit = exp.splitDetails.find(
        (s) => s.user._id.toString() === userId
      );
      const friendSplit = exp.splitDetails.find(
        (s) => s.user._id.toString() === friendId
      );
      if (!mySplit || !friendSplit) continue;

      if (payer === userId && friendSplit.status === "pending") {
        netAmount += friendSplit.finalShare;
        relatedPendingExpenses.push({
          expenseId: exp._id,
          title: exp.title,
          totalAmount: exp.amount,
          paidBy: exp.paidBy,
          mySplit,
          friendSplit,
          direction: "receive",
        });
      } else if (payer === friendId && mySplit.status === "pending") {
        netAmount -= mySplit.finalShare;
        relatedPendingExpenses.push({
          expenseId: exp._id,
          title: exp.title,
          totalAmount: exp.amount,
          paidBy: exp.paidBy,
          mySplit,
          friendSplit,
          direction: "owe",
        });
      }
    }

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

// =================================================================
// ADD TO: controllers/expenseController.js
// =================================================================
// Copy these 3 functions to the END of your expenseController.js file
// (before the last closing brace)

/**
 * ✅ Settle a specific split (Splitwise payment)
 * PATCH /expenses/:expenseId/split/:splitId/settle
 */
export const settleSplit = async (req, res, next) => {
  try {
    const { expenseId, splitId } = req.params;
    const userId = req.user.id;
    const { amount } = req.body;

    console.log(
      `\n💸 [SETTLE-SPLIT] Expense: ${expenseId}, Split: ${splitId}, Amount: ${amount}`
    );

    // Find expense
    const expense = await Expense.findById(expenseId);
    if (!expense) {
      return error(res, 404, "Expense not found");
    }

    // Find the specific split
    const split = expense.splitDetails.find(
      (s) => s._id.toString() === splitId
    );

    if (!split) {
      return error(res, 404, "Split not found");
    }

    // Authorization: Only the user who owes can settle their split
    if (split.user.toString() !== userId) {
      return error(res, 403, "You can only settle your own splits");
    }

    // Check if already settled
    if (split.status === "settled") {
      return error(res, 400, "This split is already settled");
    }

    // Mark as settled
    split.status = "settled";
    split.settledAt = new Date();

    await expense.save();

    console.log(`✅ [SETTLE-SPLIT] Successfully settled`);

    // Populate for response
    await expense.populate([
      { path: "paidBy", select: "name username email" },
      { path: "splitDetails.user", select: "name username email" },
    ]);

    return success(res, 200, {
      message: "Split settled successfully",
      expense,
    });
  } catch (err) {
    console.error("❌ [SETTLE-SPLIT-ERROR]", err);
    next(err);
  }
};

/**
 * ✅ Settle friendwise (pay net amount to friend)
 * POST /expenses/settle-friendwise
 */
export const settleFriendwise = async (req, res, next) => {
  try {
    const { friendId, amount } = req.body;
    const userId = req.user.id;

    console.log(
      `\n💰 [SETTLE-FRIENDWISE] User: ${userId}, Friend: ${friendId}, Amount: ${amount}`
    );

    if (!friendId || !amount || amount <= 0) {
      return error(res, 400, "Friend ID and valid amount required");
    }

    // Get all pending expenses where current user owes the friend
    const expenses = await Expense.find({
      paidBy: friendId,
      splitDetails: {
        $elemMatch: {
          user: userId,
          status: "pending",
        },
      },
    }).sort({ createdAt: 1 }); // Oldest first

    if (!expenses.length) {
      return error(res, 404, "No pending expenses found with this friend");
    }

    let remainingAmount = amount;
    const settledSplits = [];

    // Settle splits until amount exhausted
    for (const expense of expenses) {
      if (remainingAmount <= 0) break;

      for (const split of expense.splitDetails) {
        if (
          split.user.toString() === userId &&
          split.status === "pending" &&
          remainingAmount > 0
        ) {
          const splitAmount = split.finalShare;

          if (remainingAmount >= splitAmount) {
            // Full settlement
            split.status = "settled";
            split.settledAt = new Date();
            remainingAmount -= splitAmount;

            settledSplits.push({
              expenseId: expense._id,
              splitId: split._id,
              description: expense.description,
              amount: splitAmount,
            });

            console.log(`✅ Settled: ${expense.description} - ₹${splitAmount}`);
          }
        }
      }

      await expense.save();
    }

    console.log(
      `✅ [SETTLE-FRIENDWISE] Settled ${settledSplits.length} splits`
    );

    return success(res, 200, {
      message: "Payment processed successfully",
      settledSplits,
      amountUsed: amount - remainingAmount,
    });
  } catch (err) {
    console.error("❌ [SETTLE-FRIENDWISE-ERROR]", err);
    next(err);
  }
};

/**
 * ✅ Collect reminder (for amounts owed to you)
 * POST /expenses/send-reminder
 */
export const sendReminder = async (req, res, next) => {
  try {
    const { friendId, expenseId } = req.body;
    const userId = req.user.id;

    console.log(
      `\n📢 [SEND-REMINDER] From: ${userId}, To: ${friendId}, Expense: ${expenseId}`
    );

    const expense = await Expense.findById(expenseId).populate(
      "paidBy",
      "name username email"
    );

    if (!expense) {
      return error(res, 404, "Expense not found");
    }

    // Check if current user is the payer
    if (expense.paidBy._id.toString() !== userId) {
      return error(
        res,
        403,
        "You can only send reminders for expenses you paid"
      );
    }

    // Send notification
    await sendNotification(io, {
      userId: friendId,
      senderId: userId,
      type: "payment_reminder",
      message: `${req.user.name} sent you a reminder for ${expense.description}`,
      data: { expenseId: expense._id },
    });

    console.log(`✅ [SEND-REMINDER] Reminder sent`);

    return success(res, 200, {
      message: "Reminder sent successfully",
    });
  } catch (err) {
    console.error("❌ [SEND-REMINDER-ERROR]", err);
    next(err);
  }
};
