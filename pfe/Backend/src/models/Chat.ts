// models/Chat.ts
import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IChat extends Document {
  participants: Types.ObjectId[];    // [clientId, secretaireId]
  lastMessage?: string;
  createdAt: Date;
  updatedAt: Date;
}

const ChatSchema: Schema = new Schema<IChat>(
  {
    participants: [
      {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
      }
    ],
    lastMessage: { type: String, default: '' }
  },
  {
    timestamps: true
  }
);

// Index to speed up participant lookups
ChatSchema.index({ participants: 1 });

export default mongoose.model<IChat>('Chat', ChatSchema);
