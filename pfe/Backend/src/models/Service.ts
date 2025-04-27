import mongoose, { Schema, Document, Types } from "mongoose";

// Interface TypeScript pour un Service
export interface IService extends Document {
  _id: Types.ObjectId;
  name: string;
  description?: string;
  image?: string;
  createdAt: Date;
  updatedAt: Date;
}

// Définition du schéma Mongoose pour un Service
const ServiceSchema: Schema = new Schema<IService>(
  {
    name: {
      type: String,
      required: true,
      unique: true,
      trim: true
    },
    description: {
      type: String,
      default: null,
      trim: true
    },
    image: {
      type: String,
      default: null
    }
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform: function (doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      }
    },
    toObject: {
      virtuals: true,
      transform: function (doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      }
    }
  }
);

// Index unique sur le nom pour éviter les duplications
ServiceSchema.index({ name: 1 }, { unique: true });

// Export du modèle
const Service = mongoose.model<IService>("Service", ServiceSchema);
export default Service;
