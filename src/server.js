// ================== Core Imports ==================
import express from "express";
import http from "http";
import { Server } from "socket.io";
import dotenv from "dotenv";
import cors from "cors";
import helmet from "helmet";
import cookieParser from "cookie-parser";
import jwt from "jsonwebtoken";

// ================== Config & Utils ==================
import connectDB from "./config/db.js";
import config from "./config/config.js";
import { validateConfig } from "./config/validateConfig.js";
import logger from "./utils/logger.js";
import { registerUserSocket, removeUserSocket } from "./utils/notificationUtils.js";

// ================== Middlewares ==================
import { errorHandler } from "./middleware/errorHandler.js";
import { sanitizeXSS } from "./middleware/sanitizeXSS.js";
import { apiLimiter } from "./middleware/rateLimiter.js";
import { mongoSanitizeSafe } from "./middleware/mongoSanitizeSafe.js";

// ================== Routes ==================
import authRoutes from "./routes/authRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import expenseRoutes from "./routes/expenseRoutes.js";
import groupRoutes from "./routes/groupRoutes.js";
import friendRoutes from "./routes/friendRoutes.js";
import paymentRoutes from "./routes/paymentRoutes.js";
import settlementRoutes from "./routes/settlementRoutes.js";
import notificationRoutes from "./routes/notificationRoutes.js";

// ================== Environment & DB ==================
dotenv.config();
validateConfig();
connectDB();

// ================== App & Server Setup ==================
const app = express();
const server = http.createServer(app);

// ================== Security ==================
app.use(
  helmet({
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: false, // allow socket connections
  })
);

// Sanitize MongoDB queries
app.use(mongoSanitizeSafe);

// Rate limiting (optional)
app.use("/api", apiLimiter);

// ✅ Simple CORS setup for mobile apps
// Flutter apps don’t send browser-origin headers, so wildcard is safe.
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
  })
);

// Optional logging of request origin (for debugging)
app.use((req, res, next) => {
  console.log("📱 Request from:", req.headers["user-agent"]);
  next();
});

// ================== Global Middlewares ==================
app.use(cookieParser());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));
app.use(sanitizeXSS);

// ================== Socket.io Setup ==================
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

io.use((socket, next) => {
  try {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.split(" ")[1];

    if (!token) throw new Error("No token provided");

    const decoded = jwt.verify(token, config.jwtSecret);
    socket.userId = decoded.id;
    next();
  } catch (err) {
    logger.warn(`Socket auth failed: ${err.message}`);
    next(new Error("Unauthorized: Invalid token"));
  }
});

io.on("connection", (socket) => {
  logger.info(`🔗 Socket connected: ${socket.id} (user: ${socket.userId})`);
  registerUserSocket(socket.userId, socket.id);

  socket.on("disconnect", () => {
    if (socket.userId) removeUserSocket(socket.userId, socket.id);
    logger.info(`❌ Socket disconnected: ${socket.id}`);
  });
});

// ================== Health Check ==================
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "OK",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// ================== Routes ==================
app.get("/", (req, res) => {
  res.send("Expense Manager Backend Running ✅ (Mobile API)");
});

app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/expenses", expenseRoutes);
app.use("/api/groups", groupRoutes);
app.use("/api/friends", friendRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/settlements", settlementRoutes);
app.use("/api/notifications", notificationRoutes);

// ================== Error Handler ==================
app.use(errorHandler);

// ================== Graceful Shutdown ==================
const shutdown = async () => {
  logger.info("Shutting down gracefully...");
  await import("mongoose").then((m) => m.connection.close(false));
  server.close(() => {
    logger.info("Server closed");
    process.exit(0);
  });
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

// ================== Start Server ==================
const PORT = config.port || process.env.PORT || 8000;
server.listen(PORT, "0.0.0.0", () => {
  logger.info(`🚀 Server running on port ${PORT}`);
  logger.info(`🌍 Environment: ${config.nodeEnv}`);
});

// Export for testing
export { io, app, server };
