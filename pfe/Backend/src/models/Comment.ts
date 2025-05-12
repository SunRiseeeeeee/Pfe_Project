import mongoose, { Schema, Document, Types } from "mongoose";

export interface IComment extends Document {
  content: string; 
  createdBy: mongoose.Types.ObjectId;
  postId: mongoose.Types.ObjectId;
  createdAt: Date; 
}

const CommentSchema: Schema = new Schema({
  content: { type: String, required: true },
  createdBy: { type: Schema.Types.ObjectId, ref: "User", required: true },
  postId: { type: Schema.Types.ObjectId, ref: "Post", required: true },
  createdAt: { type: Date, default: Date.now },
});
export default mongoose.model<IComment>("Comment", CommentSchema);