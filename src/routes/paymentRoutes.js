import express from "express";
import {
  createPayment,
  submitPaymentProof,
  confirmPayment,
  getPaymentStatus,
  getPendingPaymentsToPay,
  getPendingPaymentsToConfirm,
  getPaymentHistory,
  getPaymentStats,
  cancelPayment,
} from "../controllers/paymentController.js";
import authMiddleware from "../middleware/authMiddleware.js";

const router = express.Router();

// ========== ALL ROUTES PROTECTED ==========
router.use(authMiddleware);

/**
 * ========== CREATE PAYMENT ==========
 * POST /api/payment
 * Body: { payeeId, expenseId?, amount?, method, source? }
 * 
 * Examples:
 * Splitwise: { payeeId: "...", expenseId: "...", method: "upi" }
 * Friendwise: { payeeId: "...", method: "upi" }
 */
router.post("/", createPayment);

/**
 * ========== SUBMIT PAYMENT PROOF ==========
 * POST /api/payment/:paymentId/submit-proof
 * Body: { transactionId }
 * 
 * Called after user completes UPI payment
 * Transitions: created → pending
 */
router.post("/:paymentId/submit-proof", submitPaymentProof);

/**
 * ========== CONFIRM/REJECT PAYMENT ==========
 * POST /api/payment/:paymentId/confirm
 * Body: { verified: boolean, rejectionReason?: string }
 * 
 * Only payee can call this endpoint
 * If verified=true: status → confirmed
 * If verified=false: status → rejected
 */
router.post("/:paymentId/confirm", confirmPayment);

/**
 * ========== CANCEL PAYMENT ==========
 * POST /api/payment/:paymentId/cancel
 * 
 * Only payer can cancel
 * Can only cancel if status is "created" or "pending"
 */
router.post("/:paymentId/cancel", cancelPayment);

/**
 * ========== GET SINGLE PAYMENT STATUS ==========
 * GET /api/payment/:paymentId
 * 
 * Both payer and payee can view
 */
router.get("/:paymentId", getPaymentStatus);

/**
 * ========== GET PENDING PAYMENTS (FOR PAYER) ==========
 * GET /api/payment/pending/to-pay
 * 
 * Returns all payments with status "created" or "pending"
 * that current user has to make
 */
router.get("/pending/to-pay", getPendingPaymentsToPay);

/**
 * ========== GET PENDING PAYMENTS (FOR PAYEE) ==========
 * GET /api/payment/pending/to-confirm
 * 
 * Returns all payments with status "pending"
 * waiting for current user's confirmation
 */
router.get("/pending/to-confirm", getPendingPaymentsToConfirm);

/**
 * ========== GET PAYMENT HISTORY ==========
 * GET /api/payment/history/all?limit=20&skip=0&status=confirmed
 * 
 * Returns all payments where user is payer or payee
 * Supports filtering by status
 */
router.get("/history/all", getPaymentHistory);

/**
 * ========== GET PAYMENT STATISTICS ==========
 * GET /api/payment/stats/dashboard
 * 
 * Returns:
 * - toPay: Total & count of payments user has to make
 * - toConfirm: Total & count waiting for confirmation
 * - confirmed: Total & count of completed payments
 */
router.get("/stats/dashboard", getPaymentStats);

export default router;