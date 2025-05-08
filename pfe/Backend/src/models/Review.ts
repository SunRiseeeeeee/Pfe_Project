import mongoose, { Schema, Document, Types } from "mongoose";

export interface IReview extends Document {
  client: Types.ObjectId;
  veterinarian: Types.ObjectId;
  rating?: number;
  review?: string;
  ratingCount: number; // Nombre de votes supplémentaires sur cet avis
  createdAt: Date;
  updatedAt: Date;
}

const ReviewSchema: Schema = new Schema<IReview>(
  {
    client: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    veterinarian: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    rating: {
      type: Number,
      min: 1,
      max: 5,
      required: false,
    },
    review: {
      type: String,
      trim: true,
      required: false,
    },
    // Nouveau compteur de votes sur cet avis
    ratingCount: {
      type: Number,
      default: 0,
      min: 0,
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Un client ne peut avoir qu'un seul review par vétérinaire
ReviewSchema.index({ client: 1, veterinarian: 1 }, { unique: true });

const Review = mongoose.model<IReview>("Review", ReviewSchema);
export default Review;
