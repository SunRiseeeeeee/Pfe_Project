import mongoose, { Schema, Document, Types } from "mongoose";

// Rôles possibles
export enum UserRole {
  CLIENT = "client",
  VETERINAIRE = "veterinaire",
  SECRETAIRE = "secretaire",
  ADMIN = "admin",
}

// Interface pour les horaires de travail
interface IWorkingHour {
  day: string;
  start: string; // format: "08:00"
  end: string;   // format: "17:00"
}

// Interface pour l'adresse
interface IAddress {
  street?: string;
  city?: string;
  state?: string;
  country?: string;
  postalCode?: string;
}

// Interface pour les détails supplémentaires
export interface IUserDetails {
  services?: string[];
  workingHours?: IWorkingHour[];
  specialization?: string;
  experienceYears?: number;
}

// Interface TypeScript pour un utilisateur
export interface IUser extends Document {
  _id: Types.ObjectId;
  firstName: string;
  lastName: string;
  username: string;
  email: string;
  password: string;
  phoneNumber: string;
  role: UserRole;
  profilePicture?: string;
  mapsLocation?: string;
  description?: string;
  address?: IAddress;
  details?: IUserDetails;
  reviews?: Types.ObjectId[];
  rating?: number;
  refreshToken?: string | null;
  isActive?: boolean;
  loginAttempts?: number;
  lockUntil?: Date | number | null;
  lastLogin?: Date;
  createdAt: Date;
  updatedAt: Date;
}

// Définition du schéma Mongoose
const UserSchema: Schema = new Schema<IUser>(
  {
    firstName: { type: String, required: true, trim: true },
    lastName: { type: String, required: true, trim: true },
    username: { 
      type: String, 
      required: true, 
      unique: true, 
      trim: true,
      lowercase: true 
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      match: /^\S+@\S+\.\S+$/,
    },
    password: { 
      type: String, 
      required: true, 
      select: false,
      minlength: 8 
    },
    phoneNumber: { 
      type: String, 
      required: true, 
      unique: true, 
      trim: true,
      match: /^[0-9]{8,15}$/ 
    },
    role: { 
      type: String, 
      enum: Object.values(UserRole), 
      required: true 
    },
    profilePicture: { 
      type: String, 
      default: null 
    },
    mapsLocation: { 
      type: String, 
      default: null 
    },
    description: { 
      type: String, 
      default: null, 
      trim: true 
    },
    address: {
      street: { type: String, default: null, trim: true },
      city: { type: String, default: null, trim: true },
      state: { type: String, default: null, trim: true },
      country: { type: String, default: null, trim: true },
      postalCode: { type: String, default: null, trim: true }
    },
    details: {
      services: { type: [String], default: [] },
      workingHours: [
        {
          day: { 
            type: String, 
            required: true,
            enum: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
          },
          start: { 
            type: String, 
            required: true,
            match: /^([01]\d|2[0-3]):[0-5]\d$/ // HH:MM format
          },
          end: { 
            type: String, 
            required: true,
            match: /^([01]\d|2[0-3]):[0-5]\d$/ // HH:MM format
          },
        },
      ],
      specialization: { type: String, default: null, trim: true },
      experienceYears: { 
        type: Number, 
        default: 0,
        min: 0,
        max: 100 
      }
    },
    reviews: [{ 
      type: Schema.Types.ObjectId, 
      ref: 'Review' 
    }],
    rating: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
      set: (value: number) => parseFloat(value.toFixed(2)),
    },
    refreshToken: { 
      type: String, 
      default: null, 
      select: false 
    },
    isActive: { 
      type: Boolean, 
      default: true, 
      required: true  // 👈 important !
    },
    
    loginAttempts: { 
      type: Number, 
      default: 0, 
      select: false 
    },
    lockUntil: { 
      type: Date, 
      default: null, 
      select: false 
    },
    lastLogin: { 
      type: Date, 
      default: null 
    }
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform: function(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        delete ret.password;
        delete ret.refreshToken;
        delete ret.loginAttempts;
        delete ret.lockUntil;
        return ret;
      }
    },
    toObject: {
      virtuals: true,
      transform: function(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        delete ret.password;
        delete ret.refreshToken;
        delete ret.loginAttempts;
        delete ret.lockUntil;
        return ret;
      }
    }
  }
);

// Index pour les recherches courantes
UserSchema.index({ email: 1, username: 1, phoneNumber: 1 }, { unique: true });
UserSchema.index({ 'address.city': 1, 'address.country': 1 });
UserSchema.index({ role: 1, isActive: 1 });

// Type pour les documents utilisateur avec mot de passe
export type UserWithPassword = IUser & {
  password: string;
  loginAttempts?: number;
  lockUntil?: Date | number | null;
};

const User = mongoose.model<IUser>("User", UserSchema);
export default User;