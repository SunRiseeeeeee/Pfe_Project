import mongoose, { Schema, Document, Types } from 'mongoose';
import { UserRole } from '../types';

export enum MessageType {
  TEXT = 'text',
  IMAGE = 'image',
  VIDEO = 'video'
}

export interface IMessage extends Document {
  chatId: Types.ObjectId;
  sender: Types.ObjectId;
  type: MessageType;
  content: string;      // texte ou URL image/vidéo
  createdAt: Date;
  senderInfo?: {       // virtual populated
    _id: Types.ObjectId;
    username: string;
    profilePicture?: string;
  };
}

const MessageSchema: Schema = new Schema<IMessage>(
  {
    chatId: {
      type: Schema.Types.ObjectId,
      ref: 'Chat',
      required: true
    },
    sender: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    type: {
      type: String,
      enum: Object.values(MessageType),
      default: MessageType.TEXT
    },
    content: {
      type: String,
      required: true
    }
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    toJSON: { virtuals: true },
    toObject: { virtuals: true }
  }
);

// Virtual to include sender username and profilePicture
MessageSchema.virtual('senderInfo', {
  ref: 'User',
  localField: 'sender',
  foreignField: '_id',
  justOne: true,
  options: { select: 'username profilePicture' }
});

// Index to speed up chat message retrieval
MessageSchema.index({ chatId: 1, createdAt: 1 });

export default mongoose.model<IMessage>('Message', MessageSchema);
