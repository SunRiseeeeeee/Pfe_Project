import mongoose, { Schema, Document } from "mongoose";

export interface IRating extends Document {
  client: mongoose.Types.ObjectId;
  veterinarian: mongoose.Types.ObjectId;
  rating: number;
  createdAt: Date;
  updatedAt: Date;
}

const RatingSchema: Schema = new Schema<IRating>(
  {
    client: { type: Schema.Types.ObjectId, ref: "User", required: true },
    veterinarian: { type: Schema.Types.ObjectId, ref: "User", required: true },
    rating: { type: Number, required: true, min: 0, max: 5 },
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
    toObject: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

export default mongoose.model<IRating>("Rating", RatingSchema);