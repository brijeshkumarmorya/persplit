
import User from '../models/User.js';
import { success, error } from '../utils/response.js';

/**
 * ✅ GET ALL USERS (excluding current user)
 * GET /api/users/all
 */
export const getAllUsers = async (req, res, next) => {
  try {
    console.log('\n👥 [GET-ALL-USERS] Fetching all users except current...\n');

    // Get all users except the current user
    const users = await User.find(
      { _id: { $ne: req.user.id } },
      'id _id name username email avatar'
    ).lean();

    console.log(`✅ [GET-ALL-USERS] Found ${users.length} users\n`);

    return success(res, 200, {
      users: users.map(u => ({
        id: u._id,
        _id: u._id,
        name: u.name,
        username: u.username,
        email: u.email,
        avatar: u.avatar,
      })),
    });
  } catch (err) {
    console.error('❌ [GET-ALL-USERS ERROR]', err);
    next(err);
  }
};

/**
 * ✅ SEARCH USERS
 * GET /api/users/search?query=xyz
 */
export const searchUsers = async (req, res, next) => {
  try {
    const { query } = req.query;

    if (!query || query.trim().length < 1) {
      return success(res, 200, { users: [] });
    }

    console.log(`\n🔍 [SEARCH-USERS] Query: ${query}\n`);

    const searchRegex = new RegExp(query, 'i');

    const users = await User.find(
      {
        _id: { $ne: req.user.id },
        $or: [
          { name: searchRegex },
          { email: searchRegex },
          { username: searchRegex },
        ],
      },
      'id _id name username email avatar'
    )
      .limit(20)
      .lean();

    console.log(`✅ [SEARCH-USERS] Found ${users.length} users\n`);

    return success(res, 200, {
      users: users.map(u => ({
        id: u._id,
        _id: u._id,
        name: u.name,
        username: u.username,
        email: u.email,
        avatar: u.avatar,
      })),
    });
  } catch (err) {
    console.error('❌ [SEARCH-USERS ERROR]', err);
    next(err);
  }
};

/**
 * ✅ GET USER BY ID
 * GET /api/users/:userId
 */
export const getUserById = async (req, res, next) => {
  try {
    const { userId } = req.params;

    console.log(`\n👤 [GET-USER] Fetching user: ${userId}\n`);

    const user = await User.findById(userId, 'name username email avatar upiId').lean();

    if (!user) {
      return error(res, 404, 'User not found');
    }

    return success(res, 200, {
      user: {
        id: user._id,
        name: user.name,
        username: user.username,
        email: user.email,
        avatar: user.avatar,
        upiId: user.upiId,
      },
    });
  } catch (err) {
    console.error('❌ [GET-USER ERROR]', err);
    next(err);
  }
};

/**
 * ✅ GET CURRENT USER PROFILE
 * GET /api/users/me
 */
export const getCurrentUser = async (req, res, next) => {
  try {
    console.log(`\n👤 [GET-ME] Fetching current user\n`);

    const user = await User.findById(req.user.id, 'name username email avatar').lean();

    if (!user) {
      return error(res, 404, 'User not found');
    }

    return success(res, 200, {
      user: {
        id: user._id,
        name: user.name,
        username: user.username,
        email: user.email,
        avatar: user.avatar,
      },
    });
  } catch (err) {
    console.error('❌ [GET-ME ERROR]', err);
    next(err);
  }
};

/**
 * ✅ UPDATE USER PROFILE
 * PATCH /api/users/me
 */
export const updateCurrentUser = async (req, res, next) => {
  try {
    const { name, username, email, upiId, avatar } = req.body;

    console.log(`\n✏️ [UPDATE-USER] Updating profile\n`);

    const userId = req.user.id;
    const updates = {};

    // Check if username is being changed
    if (username) {
      const existingUser = await User.findOne({
        username: username.toLowerCase(),
        _id: { $ne: userId }, // exclude current user
      });

      if (existingUser) {
        return res.status(400).json({
          success: false,
          message: "Username is already taken. Please choose another.",
        });
      }

      updates.username = username.toLowerCase();
    }

    // Check if email is being changed
    if (email) {
      const existingEmail = await User.findOne({
        email: email.toLowerCase(),
        _id: { $ne: userId },
      });

      if (existingEmail) {
        return res.status(400).json({
          success: false,
          message: "Email is already registered with another account.",
        });
      }

      updates.email = email.toLowerCase();
    }

    // Other updatable fields
    if (name) updates.name = name;
    if (upiId) updates.upiId = upiId;
    if (avatar) updates.avatar = avatar;

    // Perform update
    const user = await User.findByIdAndUpdate(userId, updates, {
      new: true,
    })
      .select("name username email upiId avatar")
      .lean();

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found.",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Profile updated successfully.",
      user: {
        id: user._id,
        name: user.name,
        username: user.username,
        email: user.email,
        upiId: user.upiId,
        avatar: user.avatar,
      },
    });
  } catch (err) {
    console.error("❌ [UPDATE-USER ERROR]", err);
    next(err);
  }
};
