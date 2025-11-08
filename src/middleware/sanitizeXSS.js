// src/middleware/sanitizeXSS.js
import xss from "xss";
import logger from "../utils/logger.js"; // optional

// Sanitize a single string value
const sanitizeValue = (value) => {
  if (typeof value === "string") {
    return xss(value, {
      whiteList: {}, // disallow all HTML tags
      stripIgnoreTag: true,
      stripIgnoreTagBody: ["script", "style"],
    }).trim();
  }
  return value;
};

// Recursively sanitize an object or array (mutates in place)
const sanitizeObject = (obj) => {
  if (!obj || typeof obj !== "object") return;

  if (Array.isArray(obj)) {
    for (let i = 0; i < obj.length; i++) {
      if (typeof obj[i] === "string") {
        obj[i] = sanitizeValue(obj[i]);
      } else if (obj[i] && typeof obj[i] === "object") {
        sanitizeObject(obj[i]); // recursive
      }
    }
  } else {
    for (const key of Object.keys(obj)) {
      if (typeof obj[key] === "string") {
        obj[key] = sanitizeValue(obj[key]);
      } else if (obj[key] && typeof obj[key] === "object") {
        sanitizeObject(obj[key]); // recursive
      }
    }
  }
};

// Middleware
export const sanitizeXSS = (req, res, next) => {
  try {
    // Skip sanitization for multipart uploads (files)
    if (req.get("Content-Type")?.includes("multipart/form-data")) {
      return next();
    }

    if (req.body) sanitizeObject(req.body);
    if (req.query) sanitizeObject(req.query);   // mutate safely
    if (req.params) sanitizeObject(req.params); // mutate safely

    next();
  } catch (error) {
    logger?.error("XSS sanitization error:", error);
    next(error);
  }
};
