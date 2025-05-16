import mongoose, { Schema, Document } from "mongoose";

export interface IReview extends Document {
  client: mongoose.Types.ObjectId;
  veterinarian: mongoose.Types.ObjectId;
  review: string;
  createdAt: Date;
  updatedAt: Date;
}

const ReviewSchema: Schema = new Schema(
  {
    client: { type: Schema.Types.ObjectId, ref: "User", required: true },
    veterinarian: { type: Schema.Types.ObjectId, ref: "User", required: true },
    review: { type: String, required: true, minlength: 10, maxlength: 500 },
  },
  { timestamps: true }
);

// Index for efficient sorting by createdAt when fetching reviews for a veterinarian
// Note: No unique index on { client, veterinarian } to allow multiple reviews from the same client
ReviewSchema.index({ veterinarian: 1, createdAt: -1 });

export default mongoose.model<IReview>("Review", ReviewSchema);