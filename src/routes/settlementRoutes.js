import express from "express";
import authMiddleware from "../middleware/authMiddleware.js";
import {
  getGlobalSettlement,
  getGroupSettlement,
  getUserSettlement,
  getExpensesToPay,
  getPaymentRequests,
  getExpensesWithFriend,
  getAmountOwedToFriend
} from "../controllers/settlementController.js";

const settlementRouter = express.Router();

// ========== Existing Routes ==========

// Global or dashboard (all balances)
settlementRouter.get("/global", authMiddleware, getGlobalSettlement);

// Group-level settlement
settlementRouter.get("/group/:groupId", authMiddleware, getGroupSettlement);

// Per-user dashboard settlement
settlementRouter.get("/user/:userId", authMiddleware, getUserSettlement);

// ========== New Routes ==========

/**
 * 🔹 Route: Get expenses I need to pay (splits)
 * GET /settlement/my-debts
 * Lists all split expenses where I owe money
 */
settlementRouter.get("/my-debts", authMiddleware, getExpensesToPay);

/**
 * 🔹 Route: Get payment requests from me
 * GET /settlement/payment-requests
 * Lists all expenses I paid for where others owe me money
 */
settlementRouter.get("/payment-requests", authMiddleware, getPaymentRequests);

/**
 * 🔹 Route: Get total amount with a specific friend
 * GET /settlement/with-friend/:friendId
 * Get all expenses with a friend and total amount due
 */
settlementRouter.get(
  "/with-friend/:friendId",
  authMiddleware,
  getExpensesWithFriend
);

/**
 * 🔹 Route: Get simple amount owed to a friend
 * GET /settlement/owed-to/:friendId
 * Get how much I owe to a specific friend
 */
settlementRouter.get(
  "/owed-to/:friendId",
  authMiddleware,
  getAmountOwedToFriend
);

export default settlementRouter;
