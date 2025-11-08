import express from 'express';
import authMiddleware from '../middleware/authMiddleware.js';
import {
  getAllUsers,
  searchUsers,
  getUserById,
  getCurrentUser,
  updateCurrentUser,
} from '../controllers/userController.js';

const router = express.Router();

// ✅ Get all users (for group creation)
router.get('/all', authMiddleware, getAllUsers);

// ✅ Search users
router.get('/search', authMiddleware, searchUsers);

// ✅ Get current user
router.get('/me', authMiddleware, getCurrentUser);

// ✅ Update current user
router.patch('/me', authMiddleware, updateCurrentUser);

// ✅ Get user by ID (must be last to avoid conflicts)
router.get('/:userId', authMiddleware, getUserById);

export default router;