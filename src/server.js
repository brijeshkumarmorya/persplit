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

// For proxy setups (Vercel, Nginx, etc.)
app.set("trust proxy", 1);

// ================== Security Middlewares ==================
app.use(
  helmet({
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: process.env.NODE_ENV === "production",
  })
);

// Sanitize MongoDB queries
app.use(mongoSanitizeSafe);

// Rate limiter for APIs
app.use("/api", apiLimiter);

// ================== CORS Setup (Flutter-Safe) ==================
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true); // Allow mobile apps / Postman
      const allowedOrigins = [config.frontendUrl];
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error("Not allowed by CORS"));
    },
    credentials: false, // Flutter mobile doesn’t use cookies
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  })
);

// Debugging CORS (can remove later)
app.use((req, res, next) => {
  console.log("🌐 Origin:", req.headers.origin);
  next();
});

// ================== Global Middlewares ==================
app.use(cookieParser());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));
app.use(sanitizeXSS);

// ================== Socket.io Setup (Optional for Render) ==================
const io = new Server(server, {
  cors: {
    origin: [config.frontendUrl],
    methods: ["GET", "POST"],
    credentials: true,
  },
});

// Authenticate sockets via JWT (disabled on Vercel)
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
    next(new Error("Unauthorized"));
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

// ================== Routes ==================
app.get("/", (req, res) => {
  res.send("Expense Manager Backend Running ✅");
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "OK",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
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

// ================== Error & Shutdown Handlers ==================
process.on("uncaughtException", (err) => {
  logger.error(`Uncaught Exception: ${err.message}`);
  process.exit(1);
});

process.on("unhandledRejection", (err) => {
  logger.error(`Unhandled Rejection: ${err.message}`);
  server.close(() => process.exit(1));
});

// ================== Local Only: Start Server ==================
if (process.env.NODE_ENV !== "production") {
  const PORT = config.port || process.env.PORT || 8000;
  server.listen(PORT, "0.0.0.0", () => {
    logger.info(`🚀 Server running locally on port ${PORT}`);
    logger.info(`📱 Frontend URL: ${config.frontendUrl}`);
    logger.info(`🌍 Environment: ${config.nodeEnv}`);
  });
}

// ================== Export for Vercel ==================
export { io, app, server };
