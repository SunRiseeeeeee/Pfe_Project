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

export interface IPost extends Document {
  photo: string;
  description: string;
  createdAt: Date;
  updatedAt: Date;
  createdBy: mongoose.Types.ObjectId;
  createdByModel: "Veterinarian";
  veterinaireId?: Types.ObjectId;
  reactions: IReaction[];
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

const PostSchema: Schema = new Schema(
  {
    photo: { type: String, required: true },
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
    reactions: [ReactionSchema]
  },
  { timestamps: true }
);





export default mongoose.model<IPost>("Post", PostSchema);