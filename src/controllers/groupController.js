import mongoose from "mongoose";
import Group from "../models/Group.js";
import Expense from "../models/Expense.js";
import User from "../models/User.js";
import { success, error } from "../utils/response.js";

// ============================================
// 1. CREATE GROUP
// ============================================
export const createGroup = async (req, res, next) => {
  try {
    const { name, members } = req.body;

    if (!name || !members?.length) {
      return error(res, 400, "Name and members are required");
    }

    if (!members.includes(req.user.id)) {
      members.push(req.user.id); // Ensure creator is a member
    }

    const group = new Group({
      name,
      members,
      createdBy: req.user.id,
    });

    await group.save();
    await group.populate("members", "name username email");
    await group.populate("createdBy", "name username email");

    console.log("✅ [CREATE-GROUP] Created:", group.name);

    return success(res, 201, { group });
  } catch (err) {
    console.error("❌ [CREATE-GROUP] Error:", err);
    next(err);
  }
};

// ============================================
// 2. GET ALL GROUPS OF LOGGED-IN USER
// ============================================
export const getMyGroups = async (req, res, next) => {
  try {
    const groups = await Group.find({ members: req.user.id })
      .populate("members", "name username email")
      .populate("createdBy", "name username email")
      .sort({ createdAt: -1 })
      .lean();

    console.log("✅ [GET-MY-GROUPS] Found:", groups.length, "groups");

    return success(res, 200, { groups });
  } catch (err) {
    console.error("❌ [GET-MY-GROUPS] Error:", err);
    next(err);
  }
};

// ============================================
// 3. GET GROUP BY ID (WITH EXPENSES & BALANCES)
// ============================================
export const getGroupById = async (req, res, next) => {
  try {
    const groupId = req.params.groupId;
    const userId = req.user.id;

    console.log("📊 [GET-GROUP] Starting for groupId:", groupId);
    console.log("📊 [GET-GROUP] User ID:", userId);

    // 1. Check if group exists
    const group = await Group.findById(groupId)
      .populate("members", "name username email upiId")
      .populate("createdBy", "name username email")
      .lean();

    console.log("📊 [GET-GROUP] Group found:", group ? "YES" : "NO");

    if (!group) return error(res, 404, "Group not found");

    // 2. Validate user belongs to group
    const isMember = group.members.some(
      (member) => member._id.toString() === userId
    );

    console.log("📊 [GET-GROUP] Is member:", isMember);

    if (!isMember) {
      return error(res, 403, "You are not a member of this group");
    }

    // 3. Fetch all expenses related to this group
    console.log("📊 [GET-GROUP] Fetching expenses...");

    const expenses = await Expense.find({ group: groupId })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 })
      .lean();

    console.log("📊 [GET-GROUP] Expenses found:", expenses.length);

    // 4. Calculate balances (you owe / you are owed)
    let youOwe = 0;
    let youAreOwed = 0;

    console.log("📊 [GET-GROUP] Calculating balances...");

    expenses.forEach((expense, index) => {
      try {
        // Safety check: ensure paidBy exists
        if (!expense.paidBy || !expense.paidBy._id) {
          console.warn(`⚠️ Expense ${index} has missing paidBy:`, expense._id);
          return; // Skip this expense
        }

        const paidById = expense.paidBy._id.toString();

        // Find current user's split in this expense
        const userSplit = expense.splitDetails?.find(
          (split) =>
            split.user && split.user._id && split.user._id.toString() === userId
        );

        if (userSplit) {
          const userShare = userSplit.finalShare || 0;

          if (paidById === userId) {
            // User paid, so others owe them
            const totalOwed =
              expense.splitDetails
                ?.filter(
                  (split) =>
                    split.user &&
                    split.user._id &&
                    split.user._id.toString() !== userId
                )
                .reduce((sum, split) => sum + (split.finalShare || 0), 0) || 0;
            youAreOwed += totalOwed;
          } else {
            // Someone else paid, user owes their share
            youOwe += userShare;
          }
        }
      } catch (expenseError) {
        console.error(
          "❌ Error processing expense:",
          expense._id,
          expenseError
        );
      }
    });

    console.log("📊 [GET-GROUP] You owe:", youOwe);
    console.log("📊 [GET-GROUP] You are owed:", youAreOwed);

    // 5. Return group details with expenses and balances
    return success(res, 200, {
      group,
      expenses,
      balance: {
        youOwe: youOwe.toFixed(2),
        youAreOwed: youAreOwed.toFixed(2),
      },
    });
  } catch (err) {
    console.error("❌ [GET-GROUP] Error:", err);
    console.error("❌ [GET-GROUP] Stack:", err.stack);
    next(err);
  }
};

// ============================================
// 4. GET EXPENSES BY GROUP ID (Separate Endpoint)
// ============================================
export const getExpensesByGroupId = async (req, res, next) => {
  try {
    const groupId = req.params.groupId;

    console.log("📋 [GET-EXPENSES] For group:", groupId);

    // 1. Check if group exists
    const group = await Group.findById(groupId);
    if (!group) return error(res, 404, "Group not found");

    // 2. Validate user belongs to group
    if (!group.members.includes(req.user.id)) {
      return error(res, 403, "You are not a member of this group");
    }

    // 3. Fetch all expenses related to this group
    const expenses = await Expense.find({ group: groupId })
      .populate("paidBy", "name username email")
      .populate("splitDetails.user", "name username email")
      .sort({ createdAt: -1 })
      .lean();

    console.log("✅ [GET-EXPENSES] Found:", expenses.length);

    return success(res, 200, { expenses });
  } catch (err) {
    console.error("❌ [GET-EXPENSES] Error:", err);
    next(err);
  }
};

// ============================================
// 5. ADD MEMBER TO GROUP
// ============================================
export const addMember = async (req, res, next) => {
  try {
    const { memberId } = req.body;
    const groupId = req.params.groupId;

    console.log("➕ [ADD-MEMBER] Adding:", memberId, "to group:", groupId);

    if (!memberId) {
      return error(res, 400, "Member ID is required");
    }

    const group = await Group.findById(groupId);
    if (!group) return error(res, 404, "Group not found");

    // Check if requester is a member
    if (!group.members.includes(req.user.id)) {
      return error(res, 403, "You are not a member of this group");
    }

    // Check if user to be added exists
    const userToAdd = await User.findById(memberId);
    if (!userToAdd) return error(res, 404, "User not found");

    // Check if already a member
    if (group.members.some((m) => m.toString() === memberId)) {
      return error(res, 400, "User is already a member");
    }

    // Add member
    group.members.push(memberId);
    await group.save();
    await group.populate("members", "name username email");
    await group.populate("createdBy", "name username email");

    console.log("✅ [ADD-MEMBER] Added:", userToAdd.name);

    return success(res, 200, {
      message: `${userToAdd.name} added to group`,
      group,
    });
  } catch (err) {
    console.error("❌ [ADD-MEMBER] Error:", err);
    next(err);
  }
};

// ============================================
// 6. REMOVE MEMBER FROM GROUP (Exit Group)
// ============================================
export const removeMember = async (req, res, next) => {
  try {
    const { memberId } = req.body;
    const groupId = req.params.groupId;
    const userId = req.user.id;

    console.log(
      "➖ [REMOVE-MEMBER] Removing:",
      memberId,
      "from group:",
      groupId
    );

    if (!memberId) {
      return error(res, 400, "Member ID is required");
    }

    const group = await Group.findById(groupId);
    if (!group) return error(res, 404, "Group not found");

    // Only allow removing yourself or if you're the creator
    if (memberId !== userId && group.createdBy.toString() !== userId) {
      return error(res, 403, "You can only remove yourself from the group");
    }

    // Check if user has pending dues
    const expenses = await Expense.find({ group: group._id });
    let totalBalance = 0;

    console.log("💰 [REMOVE-MEMBER] Checking balance for:", memberId);

    expenses.forEach((expense) => {
      const paidById = expense.paidBy.toString();

      // Find user's split in this expense
      const userSplit = expense.splitDetails?.find(
        (split) => split.user.toString() === memberId
      );

      if (userSplit) {
        if (paidById === memberId) {
          // User paid - others owe them
          const othersOwed = expense.splitDetails
            .filter((split) => split.user.toString() !== memberId)
            .reduce((sum, split) => sum + (split.finalShare || 0), 0);
          totalBalance += othersOwed;
        } else {
          // Someone else paid - user owes
          totalBalance -= userSplit.finalShare || 0;
        }
      }
    });

    console.log("💰 [REMOVE-MEMBER] Total balance:", totalBalance);

    if (totalBalance < -0.01) {
      // Using small threshold to handle floating point
      return error(
        res,
        400,
        `Cannot leave group. You owe ₹${Math.abs(totalBalance).toFixed(
          2
        )}. Please settle all dues first.`
      );
    }

    // Remove member
    group.members = group.members.filter((m) => m.toString() !== memberId);
    await group.save();
    await group.populate("members", "name username email");

    console.log("✅ [REMOVE-MEMBER] Success");

    return success(res, 200, {
      message:
        memberId === userId
          ? "You left the group successfully"
          : "Member removed successfully",
      group,
    });
  } catch (err) {
    console.error("❌ [REMOVE-MEMBER] Error:", err);
    next(err);
  }
};

// ============================================
// 7. UPDATE GROUP
// ============================================
export const updateGroup = async (req, res, next) => {
  try {
    const { name, description } = req.body;
    const groupId = req.params.groupId;

    console.log("✏️ [UPDATE-GROUP] Updating group:", groupId);

    const group = await Group.findById(groupId);
    if (!group) return error(res, 404, "Group not found");

    // Only creator can update
    if (group.createdBy.toString() !== req.user.id) {
      return error(res, 403, "Only group creator can update group details");
    }

    if (name) group.name = name;
    if (description !== undefined) group.description = description;

    await group.save();
    await group.populate("members", "name username email");
    await group.populate("createdBy", "name username email");

    console.log("✅ [UPDATE-GROUP] Updated successfully");

    return success(res, 200, {
      message: "Group updated successfully",
      group,
    });
  } catch (err) {
    console.error("❌ [UPDATE-GROUP] Error:", err);
    next(err);
  }
};

// ============================================
// 8. DELETE GROUP
// ============================================
export const deleteGroup = async (req, res, next) => {
  try {
    const groupId = req.params.groupId;

    console.log("🗑️ [DELETE-GROUP] Deleting group:", groupId);

    const group = await Group.findById(groupId);
    if (!group) return error(res, 404, "Group not found");

    // Only creator can delete
    if (group.createdBy.toString() !== req.user.id) {
      return error(res, 403, "Only group creator can delete the group");
    }

    // Check if there are any expenses
    const expenseCount = await Expense.countDocuments({ group: groupId });

    console.log("📋 [DELETE-GROUP] Expenses in group:", expenseCount);

    if (expenseCount > 0) {
      return error(
        res,
        400,
        "Cannot delete group with existing expenses. Settle all expenses first."
      );
    }

    await Group.findByIdAndDelete(groupId);

    console.log("✅ [DELETE-GROUP] Deleted successfully");

    return success(res, 200, {
      message: "Group deleted successfully",
    });
  } catch (err) {
    console.error("❌ [DELETE-GROUP] Error:", err);
    next(err);
  }
};
