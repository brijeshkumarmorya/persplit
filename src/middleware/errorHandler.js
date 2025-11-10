// src/middleware/errorHandler.js
import { error } from "../utils/response.js";
import logger from "../utils/logger.js";

// Global error handler middleware
export const errorHandler = (err, req, res, next) => {
  // ✅ FIX: Check headers sent to prevent double response
  if (res.headersSent) {
    logger.error("🔥 Response already sent, cannot send error:", err.message);
    return next(err);
  }

  logger.error("🔥 Internal Error:", err); // log full error on server

  // Extract status code and message
  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || "Internal Server Error";

  // ✅ Better error logging for debugging
  logger.error({
    message: message,
    status: statusCode,
    stack: err.stack,
    url: req.url,
    method: req.method,
  });

  // Generic message to client (don't expose internals in production)
  const clientMessage =
    process.env.NODE_ENV === "production"
      ? "Something went wrong, please try again"
      : message;

  return error(res, statusCode, clientMessage);
};