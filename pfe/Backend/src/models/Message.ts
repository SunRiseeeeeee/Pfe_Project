import mongoose, { Schema, Document, Types } from 'mongoose';

// Enum for message types
export enum MessageType {
  TEXT = 'text',
  IMAGE = 'image',
  VIDEO = 'video',
  FILE = 'file',
  AUDIO = 'audio',
}

// Interface for the message document
export interface IMessage extends Document {
  chatId: Types.ObjectId;
  sender: Types.ObjectId;
  type: MessageType;
  content: string;
  readBy: Types.ObjectId[];
  createdAt: Date;
  updatedAt?: Date;
  senderInfo?: {
    _id: Types.ObjectId;
    firstName: string;
    lastName: string;
    username: string;
    profilePicture?: string;
    role: string;
  };
}

// Define the schema
const MessageSchema: Schema<IMessage> = new Schema<IMessage>(
  {
    chatId: {
      type: Schema.Types.ObjectId,
      ref: 'Chat',
      required: true,
      index: true,
    },
    sender: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: Object.values(MessageType),
      default: MessageType.TEXT,
      required: true,
    },
    content: {
      type: String,
      required: true,
      trim: true,
      maxlength: 2000,
      validate: {
        validator: function (content: string) {
          return !(this.type === MessageType.TEXT && content.length > 2000);
        },
        message: 'Le message texte ne peut pas dépasser 2000 caractères',
      },
    },
    readBy: [
      {
        type: Schema.Types.ObjectId,
        ref: 'User',
        default: [],
      },
    ],
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform: function (doc: Document, ret: Record<string, any>) {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
    toObject: {
      virtuals: true,
      transform: function (doc: Document, ret: Record<string, any>) {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

// Virtual for sender information
MessageSchema.virtual('senderInfo', {
  ref: 'User',
  localField: 'sender',
  foreignField: '_id',
  justOne: true,
  options: {
    select: 'firstName lastName username profilePicture role',
  },
});

// Indexes
MessageSchema.index({ chatId: 1, createdAt: -1 }); // For retrieving recent messages in a chat
MessageSchema.index({ sender: 1, createdAt: -1 }); // For finding messages by user
MessageSchema.index({ readBy: 1 }); // For queries on read messages

// Middleware to validate content before saving
MessageSchema.pre<IMessage>('save', function (next) {
  if (
    this.isModified('content') &&
    this.type === MessageType.TEXT &&
    this.content.length > 2000
  ) {
    return next(new Error('Le message texte ne peut pas dépasser 2000 caractères'));
  }
  next();
});

// Export the model
export default mongoose.model<IMessage>('Message', MessageSchema);