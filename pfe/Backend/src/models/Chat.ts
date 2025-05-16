import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IChatMessage {
  senderId: Types.ObjectId;
  content: string;
  timestamp: Date;
}

export interface IChat extends Document {
  participants: Types.ObjectId[];
  veterinaireId?: Types.ObjectId;
  messages: IChatMessage[];
  lastMessage?: Types.ObjectId;
  unreadCount: number;
  createdAt: Date;
  updatedAt: Date;
}

const ChatSchema = new Schema<IChat>(
  {
    participants: {
      type: [{
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
      }],
      validate: {
        validator: (arr: Types.ObjectId[]) => arr.length >= 2,
        message: 'Un chat doit avoir au moins deux participants'
      }
    },
    veterinaireId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      index: true
    },
    messages: [{
      senderId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
      content: { type: String, required: true },
      timestamp: { type: Date, default: Date.now }
    }],
    lastMessage: {
      type: Schema.Types.ObjectId,
      ref: 'Message',
      index: true
    },
    unreadCount: {
      type: Number,
      default: 0,
      min: 0
    }
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform: (doc, ret) => {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
      }
    }
  }
);

// Indexes et virtuals...
ChatSchema.index({ participants: 1 });
ChatSchema.index({ veterinaireId: 1 });
ChatSchema.index({ updatedAt: -1 });

export default mongoose.model<IChat>('Chat', ChatSchema);