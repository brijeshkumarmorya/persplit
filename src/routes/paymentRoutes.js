import express from "express";
import auth from "../middleware/authMiddleware.js";
import {
  getPayeeDetails,
  submitPayment,
  verifyPayment,
  cancelPayment,
  getPaymentStatus,
  getPendingPaymentsToPay,
  getPendingPaymentsToConfirm,
} from "../controllers/paymentController.js";

const router = express.Router();

// All routes protected
router.use(auth);

// STEP 1: Get payee UPI before submit
router.get("/payee/:payeeId", getPayeeDetails);

// STEP 2: Submit payment after user pays
router.post("/submit", submitPayment);

// STEP 3: Payee verify (approve/reject)
router.post("/:paymentId/verify", verifyPayment);

// Payer cancel
router.post("/:paymentId/cancel", cancelPayment);

// GET pending payments for payer
router.get("/pending/to-pay", getPendingPaymentsToPay);

// GET pending payments for payee
router.get("/pending/to-confirm", getPendingPaymentsToConfirm);

// Get single payment status
router.get("/:paymentId", getPaymentStatus);

export default router;
