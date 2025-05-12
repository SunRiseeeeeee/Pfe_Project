import mongoose, { Schema, Document, Types } from "mongoose";

export interface IReactionUserDetails {
  firstName: string;
  lastName: string;
  profilePicture?: string;
}

export interface IReaction {
  userId: Types.ObjectId;
  type: "j'aime" | "j'adore" | "triste" | "j'admire";
  userDetails?: IReactionUserDetails;
}

export interface IComment {
  _id?: Types.ObjectId; // Made optional to fix TS2741
  userId: Types.ObjectId;
  content: string;
  userDetails?: IReactionUserDetails;
  reactions: IReaction[];
  createdAt: Date;
  updatedAt: Date;
}

export interface IPost extends Document {
  media: string;
  mediaType: "image" | "video";
  description: string;
  createdAt: Date;
  updatedAt: Date;
  createdBy: mongoose.Types.ObjectId;
  createdByModel: "Veterinarian";
  veterinaireId?: Types.ObjectId;
  reactions: IReaction[];
  comments: IComment[];
}

const ReactionSchema = new Schema({
  userId: { 
    type: Schema.Types.ObjectId, 
    ref: "User",
    required: true 
  },
  type: { 
    type: String, 
    enum: ["j'aime", "j'adore", "triste", "j'admire"],
    required: true 
  },
  userDetails: {
    firstName: { type: String },
    lastName: { type: String },
    profilePicture: { type: String }
  }
}, { _id: false });

const CommentSchema = new Schema({
  userId: {
    type: Schema.Types.ObjectId,
    ref: "User",
    required: true
  },
  content: {
    type: String,
    required: true
  },
  userDetails: {
    firstName: { type: String },
    lastName: { type: String },
    profilePicture: { type: String }
  },
  reactions: [ReactionSchema]
}, { timestamps: true });

const PostSchema: Schema = new Schema(
  {
    media: { type: String, required: true },
    mediaType: { 
      type: String, 
      enum: ["image", "video"], 
      
    },
    description: { type: String, required: true },
    createdBy: {
      type: Schema.Types.ObjectId,
      refPath: "createdByModel",
      required: true,
    },
    createdByModel: {
      type: String,
      required: true,
      enum: ["Veterinarian"],
    },
    veterinaireId: {
      type: Schema.Types.ObjectId,
      ref: "Veterinarian",
      required: false,
    },
    reactions: [ReactionSchema],
    comments: [CommentSchema]
  },
  { timestamps: true }
);

export default mongoose.model<IPost>("Post", PostSchema);