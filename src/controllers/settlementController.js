import mongoose from "mongoose";
import Expense from "../models/Expense.js";
import { computeSettlement } from "../utils/expenseUtils.js";
import { success, error } from "../utils/response.js";

/**
 * Helper → run aggregation to compute balances
 */
const aggregateBalances = async (matchStage) => {
  const balances = await Expense.aggregate([
    { $match: matchStage },
    { $unwind: "$splitDetails" },
    {
      $group: {
        _id: "$splitDetails.user",
        balance: {
          $sum: {
            $cond: [
              { $eq: ["$paidBy", "$splitDetails.user"] },
              "$amount", // if user is payer, add full amount
              { $multiply: [-1, "$splitDetails.finalShare"] } // else subtract their share
            ]
          }
        }
      }
    }
  ]);

  // Convert aggregation result → object { userId: balance }
  const combinedBalances = {};
  balances.forEach((b) => {
    combinedBalances[b._id.toString()] =
      Math.round(b.balance * 100) / 100; // round 2 decimals
  });

  return combinedBalances;
};

/**
 * 🔹 Global settlement (all users OR specific user dashboard)
 */
export const getGlobalSettlement = async (req, res, next) => {
  try {
    const { userId } = req.query;
    const matchStage = userId
      ? {
          $or: [
            { paidBy: new mongoose.Types.ObjectId(userId) },
            { "splitDetails.user": new mongoose.Types.ObjectId(userId) }
          ]
        }
      : {};

    const combinedBalances = await aggregateBalances(matchStage);

    if (!combinedBalances || Object.keys(combinedBalances).length === 0) {
      return error(res, 404, "No expenses found");
    }

    const transfers = computeSettlement(combinedBalances);

    return success(res, 200, {
      scope: userId ? `Dashboard for ${userId}` : "Global settlement",
      balances: combinedBalances,
      transfers
    });
  } catch (err) {
    next(err);
  }
};

/**
 * 🔹 Group-level settlement
 */
export const getGroupSettlement = async (req, res, next) => {
  try {
    const { groupId } = req.params;
    const matchStage = { group: new mongoose.Types.ObjectId(groupId) };

    const combinedBalances = await aggregateBalances(matchStage);

    if (!combinedBalances || Object.keys(combinedBalances).length === 0) {
      return error(res, 404, "No expenses found in this group");
    }

    const transfers = computeSettlement(combinedBalances);

    return success(res, 200, {
      scope: `Group ${groupId} settlement`,
      balances: combinedBalances,
      transfers
    });
  } catch (err) {
    next(err);
  }
};

/**
 * 🔹 Per-user settlement (dashboard view)
 */
export const getUserSettlement = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const matchStage = {
      $or: [
        { paidBy: new mongoose.Types.ObjectId(userId) },
        { "splitDetails.user": new mongoose.Types.ObjectId(userId) }
      ]
    };

    const combinedBalances = await aggregateBalances(matchStage);

    if (!combinedBalances || Object.keys(combinedBalances).length === 0) {
      return error(res, 404, "No expenses found for this user");
    }

    const transfers = computeSettlement(combinedBalances);

    // Filter only transfers involving this user
    const userTransfers = transfers.filter(
      (t) => t.from === userId || t.to === userId
    );

    return success(res, 200, {
      scope: `User ${userId} settlement`,
      balance: combinedBalances[userId] || 0,
      transfers: userTransfers
    });
  } catch (err) {
    next(err);
  }
};

/**
 * 🔹 Get expenses I need to pay (splits where I owe money)
 * Lists all split expenses where current user owes money
 */
export const getExpensesToPay = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const pageNum = Number(page) || 1;
    const limitNum = Number(limit) || 10;
    const skip = (pageNum - 1) * limitNum;

    // Find all expenses where this user is in splitDetails but NOT the payer
    const expenses = await Expense.find({
      "splitDetails.user": new mongoose.Types.ObjectId(userId),
      paidBy: { $ne: new mongoose.Types.ObjectId(userId) }
    })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    const total = await Expense.countDocuments({
      "splitDetails.user": new mongoose.Types.ObjectId(userId),
      paidBy: { $ne: new mongoose.Types.ObjectId(userId) }
    });

    // Add user's share and amount they owe
    const expensesWithDetails = expenses.map((exp) => {
      const userSplit = exp.splitDetails.find(
        (s) => s.user._id.toString() === userId
      );

      return {
        ...exp,
        myShare: userSplit?.finalShare || 0,
        amountOwed: userSplit?.finalShare || 0,
        paidByName: exp.paidBy.name
      };
    });

    return success(res, 200, {
      message: "Expenses to pay",
      expenses: expensesWithDetails,
      total,
      page: pageNum,
      limit: limitNum,
      totalPages: Math.ceil(total / limitNum)
    });
  } catch (err) {
    next(err);
  }
};

/**
 * 🔹 Get payment request route (someone needs to pay me)
 * Lists all expenses I paid for where others owe me money
 */
export const getPaymentRequests = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const pageNum = Number(page) || 1;
    const limitNum = Number(limit) || 10;
    const skip = (pageNum - 1) * limitNum;

    // Find all expenses where this user is the payer
    const expenses = await Expense.find({
      paidBy: new mongoose.Types.ObjectId(userId),
      "splitDetails.0": { $exists: true } // has split details
    })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    const total = await Expense.countDocuments({
      paidBy: new mongoose.Types.ObjectId(userId),
      "splitDetails.0": { $exists: true }
    });

    // Add amount each person owes me
    const expensesWithDetails = expenses.map((exp) => {
      const splitData = exp.splitDetails.map((split) => ({
        user: split.user,
        amountOwed: split.finalShare
      }));

      return {
        ...exp,
        splitData,
        totalAmount: exp.amount
      };
    });

    return success(res, 200, {
      message: "Payment requests",
      expenses: expensesWithDetails,
      total,
      page: pageNum,
      limit: limitNum,
      totalPages: Math.ceil(total / limitNum)
    });
  } catch (err) {
    next(err);
  }
};

/**
 * 🔹 Get total expenses with a specific friend
 * Get all expenses between me and a specific friend (total amount due)
 */
export const getExpensesWithFriend = async (req, res, next) => {
  try {
    const currentUserId = req.user.id;
    const { friendId } = req.params;

    if (!friendId) {
      return error(res, 400, "Friend ID is required");
    }

    // Validate ObjectId
    if (!mongoose.Types.ObjectId.isValid(friendId)) {
      return error(res, 400, "Invalid friend ID format");
    }

    const friendObjectId = new mongoose.Types.ObjectId(friendId);
    const currentUserObjectId = new mongoose.Types.ObjectId(currentUserId);

    // Find all expenses between two users
    const expenses = await Expense.find({
      $or: [
        {
          paidBy: currentUserObjectId,
          "splitDetails.user": friendObjectId
        },
        {
          paidBy: friendObjectId,
          "splitDetails.user": currentUserObjectId
        }
      ]
    })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 })
      .lean();

    if (!expenses || expenses.length === 0) {
      return success(res, 200, {
        message: "No expenses found with this friend",
        friendId,
        totalExpenses: 0,
        amountIOweFriend: 0,
        amountFriendOwesMe: 0,
        expenses: []
      });
    }

    // Calculate totals
    let amountIOweFriend = 0;
    let amountFriendOwesMe = 0;

    const expensesWithDetails = expenses.map((exp) => {
      let relationshipAmount = 0;

      if (exp.paidBy._id.toString() === currentUserId) {
        // I paid, friend owes me
        const friendShare = exp.splitDetails.find(
          (s) => s.user._id.toString() === friendId
        );
        relationshipAmount = friendShare?.finalShare || 0;
        amountFriendOwesMe += relationshipAmount;
      } else {
        // Friend paid, I owe friend
        const myShare = exp.splitDetails.find(
          (s) => s.user._id.toString() === currentUserId
        );
        relationshipAmount = myShare?.finalShare || 0;
        amountIOweFriend += relationshipAmount;
      }

      return {
        expenseId: exp._id,
        description: exp.description,
        amount: exp.amount,
        paidBy: exp.paidBy.name,
        paidById: exp.paidBy._id,
        paidByMe: exp.paidBy._id.toString() === currentUserId,
        relationshipAmount,
        createdAt: exp.createdAt
      };
    });

    // Calculate net settlement
    const netAmount = amountFriendOwesMe - amountIOweFriend;

    return success(res, 200, {
      message: "Expenses with friend",
      friendId,
      totalExpenses: expenses.length,
      amountIOweFriend: Math.round(amountIOweFriend * 100) / 100,
      amountFriendOwesMe: Math.round(amountFriendOwesMe * 100) / 100,
      netSettlement: Math.round(netAmount * 100) / 100,
      settlementMessage:
        netAmount > 0
          ? `Friend owes you ₹${Math.abs(netAmount).toFixed(2)}`
          : netAmount < 0
          ? `You owe friend ₹${Math.abs(netAmount).toFixed(2)}`
          : "All settled",
      expenses: expensesWithDetails
    });
  } catch (err) {
    next(err);
  }
};

/**
 * 🔹 Get total amount I owe to a specific friend
 * Simple endpoint to get how much I owe to a friend
 */
export const getAmountOwedToFriend = async (req, res, next) => {
  try {
    const currentUserId = req.user.id;
    const { friendId } = req.params;

    if (!friendId) {
      return error(res, 400, "Friend ID is required");
    }

    if (!mongoose.Types.ObjectId.isValid(friendId)) {
      return error(res, 400, "Invalid friend ID format");
    }

    const friendObjectId = new mongoose.Types.ObjectId(friendId);
    const currentUserObjectId = new mongoose.Types.ObjectId(currentUserId);

    // Find expenses where friend paid and I owe them
    const expenses = await Expense.find({
      paidBy: friendObjectId,
      "splitDetails.user": currentUserObjectId
    }).lean();

    let totalOwed = 0;
    expenses.forEach((exp) => {
      const myShare = exp.splitDetails.find(
        (s) => s.user.toString() === currentUserId
      );
      totalOwed += myShare?.finalShare || 0;
    });

    // Find expenses where I paid and friend owes me
    const expensesWhereIpaid = await Expense.find({
      paidBy: currentUserObjectId,
      "splitDetails.user": friendObjectId
    }).lean();

    let totalFriendOwesMe = 0;
    expensesWhereIpaid.forEach((exp) => {
      const friendShare = exp.splitDetails.find(
        (s) => s.user.toString() === friendId
      );
      totalFriendOwesMe += friendShare?.finalShare || 0;
    });

    const netAmount = totalFriendOwesMe - totalOwed;

    return success(res, 200, {
      friendId,
      amountIOweFriend: Math.round(totalOwed * 100) / 100,
      amountFriendOwesMe: Math.round(totalFriendOwesMe * 100) / 100,
      netAmount: Math.round(netAmount * 100) / 100,
      status:
        netAmount > 0
          ? "friend_owes_me"
          : netAmount < 0
          ? "i_owe_friend"
          : "settled"
    });
  } catch (err) {
    next(err);
  }
};
