// models/Chat.ts
import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IChat extends Document {
  participants: Types.ObjectId[];
  lastMessage?: Types.ObjectId;
  unreadCount: number;
  createdAt: Date;
  updatedAt: Date;
  participantsInfo?: {
    _id: Types.ObjectId;
    firstName: string;
    lastName: string;
    profilePicture?: string;
    role: string;
  }[];
}

const ChatSchema: Schema = new Schema<IChat>(
  {
    participants: {
      type: [{
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
      }],
      validate: {
        validator: function(participants: Types.ObjectId[]) {
          return participants.length === 2;
        },
        message: 'Un chat doit avoir exactement deux participants'
      }
    },
    lastMessage: {
      type: Schema.Types.ObjectId,
      ref: 'Message',
      default: null
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
      transform: function(doc, ret, options) {
        const chatDoc = doc as unknown as IChat & { _id: Types.ObjectId };
        delete ret.__v;
        delete ret._id;
        ret.id = chatDoc._id.toString();
        return ret;
      }
    },
    toObject: { 
      virtuals: true,
      transform: function(doc, ret, options) {
        const chatDoc = doc as unknown as IChat & { _id: Types.ObjectId };
        delete ret.__v;
        delete ret._id;
        ret.id = chatDoc._id.toString();
        return ret;
      }
    }
  }
);

// Virtual pour les infos des participants
ChatSchema.virtual('participantsInfo', {
  ref: 'User',
  localField: 'participants',
  foreignField: '_id',
  options: { 
    select: 'firstName lastName profilePicture role' 
  }
});

// Index pour optimiser les recherches
ChatSchema.index({ participants: 1 });
ChatSchema.index({ lastMessage: 1 });
ChatSchema.index({ updatedAt: -1 });

export default mongoose.model<IChat>('Chat', ChatSchema);