import express from "express";
import authMiddleware from "../middleware/authMiddleware.js";
import validateSplitFriends from "../middleware/validateSplitFriends.js";
import { expenseValidation } from "../validators/expenseValidators.js";
import { validate } from "../middleware/validate.js";
import {
  addExpense,
  deleteExpense,
  getAllExpenses,
  getExpenseSettlement,
  getPendingExpenses,
  getNetAmountWithUser,
  settleSplit,
  settleFriendwise,
  sendReminder           
} from "../controllers/expenseController.js";

const expenseRouter = express.Router();

// Existing routes
expenseRouter.post("/add", authMiddleware, expenseValidation, validate, validateSplitFriends, addExpense);
expenseRouter.get("/", authMiddleware, getAllExpenses);
expenseRouter.get("/:expenseId/settlement", authMiddleware, getExpenseSettlement);
expenseRouter.delete("/:expenseId", authMiddleware, deleteExpense);
expenseRouter.get("/pending-expenses", authMiddleware, getPendingExpenses);
expenseRouter.get("/net-with/:friendId", authMiddleware, getNetAmountWithUser);

// ✅ NEW SETTLEMENT ROUTES
expenseRouter.patch("/:expenseId/split/:splitId/settle", authMiddleware, settleSplit);
expenseRouter.post("/settle-friendwise", authMiddleware, settleFriendwise);
expenseRouter.post("/send-reminder", authMiddleware, sendReminder);

export default expenseRouter;