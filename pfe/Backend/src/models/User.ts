import mongoose, { Schema, Document, Types } from "mongoose";

// Rôles possibles
export enum UserRole {
  CLIENT = "client",
  VETERINAIRE = "veterinaire",
  SECRETAIRE = "secretaire",
  ADMIN = "admin",
  SECRETARIEN = "SECRETARIEN",
}

// Interface pour les horaires de travail incluant une pause
interface IWorkingHour {
  day: string;
  start: string;
  pauseStart?: string;
  pauseEnd?: string;
  end: string;
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
  veterinaireId?: Types.ObjectId;
  profilePicture?: string;
  mapsLocation?: string;
  description?: string;
  address?: IAddress;
  details?: IUserDetails;

  refreshToken?: string | null;
  isActive?: boolean;
  loginAttempts?: number;
  lockUntil?: Date | null;
  lastLogin?: Date;
  resetPasswordCode?: string | null;
  resetPasswordExpires?: Date | null;
  createdAt: Date;
  updatedAt: Date;

}

const UserSchema: Schema = new Schema<IUser>(
  {
    firstName: { type: String, required: true, trim: true },
    lastName: { type: String, required: true, trim: true },
    username: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      match: /^\S+@\S+\.\S+$/,
    },
    password: { type: String, required: true, select: false, minlength: 8 },
    phoneNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      match: /^[0-9]{8,15}$/,
    },
    role: {
      type: String,
      enum: Object.values(UserRole),
      required: true,
      validate: {
        validator: function (value: string) {
          return Object.values(UserRole).includes(value as UserRole);
        },
        message: 'Role invalide',
      },
    },
    veterinaireId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: function () {
        return this.role === UserRole.SECRETAIRE;
      },
    },
    profilePicture: { type: String, default: null },
    mapsLocation: { type: String, default: null },
    description: { type: String, default: null, trim: true },
    address: {
      street: { type: String, default: null, trim: true },
      city: { type: String, default: null, trim: true },
      state: { type: String, default: null, trim: true },
      country: { type: String, default: null, trim: true },
      postalCode: { type: String, default: null, trim: true },
    },
    details: {
      services: { type: [String], default: [] },
      workingHours: [
        {
          day: {
            type: String,
            required: true,
            enum: [
              "Monday",
              "Tuesday",
              "Wednesday",
              "Thursday",
              "Friday",
              "Saturday",
              "Sunday",
            ],
          },
          start: {
            type: String,
            required: true,
            match: /^([01]\d|2[0-3]):[0-5]\d$/,
          },
          pauseStart: {
            type: String,
            default: null,
            match: /^([01]\d|2[0-3]):[0-5]\d$/,
          },
          pauseEnd: {
            type: String,
            default: null,
            match: /^([01]\d|2[0-3]):[0-5]\d$/,
          },
          end: {
            type: String,
            required: true,
            match: /^([01]\d|2[0-3]):[0-5]\d$/,
          },
        },
      ],
      specialization: { type: String, default: null, trim: true },
      experienceYears: { type: Number, default: 0, min: 0, max: 100 },
    },


    refreshToken: { type: String, default: null, select: false },
    isActive: { type: Boolean, default: true },
    loginAttempts: { type: Number, default: 0, select: false },
    lockUntil: { type: Date, default: null, select: false },
    lastLogin: { type: Date, default: null },
    resetPasswordCode: { type: String, default: null, select: false },
    resetPasswordExpires: { type: Date, default: null, select: false },
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        delete ret.password;
        delete ret.refreshToken;
        delete ret.loginAttempts;
        delete ret.lockUntil;
        delete ret.resetPasswordCode;
        delete ret.resetPasswordExpires;
        return ret;
      },
    },
    toObject: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        delete ret.password;
        delete ret.refreshToken;
        delete ret.loginAttempts;
        delete ret.lockUntil;
        delete ret.resetPasswordCode;
        delete ret.resetPasswordExpires;
        return ret;
      },
    },
  }
);

// Indexes
UserSchema.index({ email: 1, username: 1, phoneNumber: 1 }, { unique: true });
UserSchema.index({ "address.city": 1, "address.country": 1 });
UserSchema.index({ role: 1, isActive: 1 });
UserSchema.index({ ratedVeterinarians: 1 });


const User = mongoose.model<IUser>("User", UserSchema);
export default User;