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
  getNetAmountWithUser
} from "../controllers/expenseController.js";

const expenseRouter = express.Router();

expenseRouter.post("/add", authMiddleware, expenseValidation, validate, validateSplitFriends, addExpense);

expenseRouter.get("/", authMiddleware, getAllExpenses);

expenseRouter.get("/:expenseId/settlement", authMiddleware, getExpenseSettlement);

expenseRouter.delete("/:expenseId", authMiddleware, deleteExpense);

expenseRouter.get(
  "/pending-expenses",
  authMiddleware,
  getPendingExpenses
);

expenseRouter.get("/net-with/:friendId", authMiddleware, getNetAmountWithUser);

export default expenseRouter;
