import mongoose from "mongoose";

const paymentSchema = new mongoose.Schema(
  {
    payer: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    payee: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },

    amount: { type: Number, required: true, min: 1 },

    // method chosen by user while submitting payment
    method: { type: String, enum: ["upi", "cash"], required: true },

    // status starts directly at "pending" after user hits submit
    status: { 
      type: String, 
      enum: ["pending", "confirmed", "rejected"], 
      default: "pending", 
      index: true 
    },

    transactionId: { type: String, default: null }, // optional for UPI

    note: { type: String, default: null },
    rejectionReason: { type: String, default: null },

    source: { type: String, enum: ["splitwise", "friendwise"], default: "splitwise" },

    relatedExpenses: [{ type: mongoose.Schema.Types.ObjectId, ref: "Expense" }],

    confirmedAt: { type: Date, default: null },
  },
  { timestamps: true }
);


// 🔒 Prevent creating multiple payments for same expenses
paymentSchema.pre("save", async function (next) {
  const Payment = mongoose.model("Payment");

  if (this.relatedExpenses && this.relatedExpenses.length > 0) {
    const existing = await Payment.findOne({
      relatedExpenses: { $in: this.relatedExpenses },
      _id: { $ne: this._id },
      status: { $in: ["pending"] }
    });

    if (existing) {
      return next(
        new Error(
          `This expense is already linked to another active payment (${existing._id}).`
        )
      );
    }
  }
  next();
});

paymentSchema.index({ payer: 1, status: 1 });
paymentSchema.index({ payee: 1, status: 1 });
paymentSchema.index({ createdAt: -1 });

const Payment = mongoose.model("Payment", paymentSchema);
export default Payment;
