import mongoose from "mongoose";

const paymentSchema = new mongoose.Schema(
  {
    payer: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    payee: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    amount: { type: Number, required: true, min: 0 },
    method: { type: String, enum: ["upi", "cash"], default: "upi", required: true },
    status: { type: String, enum: ["created", "pending", "confirmed", "rejected"], default: "created", index: true },
    upiIntent: { type: String, default: null },
    qrData: { type: String, default: null },
    transactionId: { type: String, default: null },
    note: { type: String, default: null },
    rejectionReason: { type: String, default: null },
    source: { type: String, enum: ["splitwise", "friendwise"], default: "splitwise" },
    relatedExpenses: [{ type: mongoose.Schema.Types.ObjectId, ref: "Expense" }],
    createdAt: { type: Date, default: Date.now, index: true },
    confirmedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// 🧠 Pre-save hook to prevent duplicate expense references
paymentSchema.pre("save", async function (next) {
  const Payment = mongoose.model("Payment");
  if (this.relatedExpenses && this.relatedExpenses.length > 0) {
    const existing = await Payment.findOne({
      relatedExpenses: { $in: this.relatedExpenses },
      _id: { $ne: this._id },
    });
    if (existing) {
      return next(
        new Error(
          `One or more related expenses are already linked to another payment (${existing._id}).`
        )
      );
    }
  }
  next();
});

paymentSchema.index({ payer: 1, status: 1 });
paymentSchema.index({ payee: 1, status: 1 });
paymentSchema.index({ payer: 1, payee: 1, status: 1 });
paymentSchema.index({ createdAt: -1 });

const Payment = mongoose.model("Payment", paymentSchema);
export default Payment;
