import mongoose, { Schema, Document } from "mongoose";

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

// Interface pour les détails supplémentaires
export interface IUserDetails {
  services?: string[];  // Liste de services
  workingHours?: IWorkingHour[];
}

// Interface TypeScript pour un utilisateur
export interface IUser extends Document {
  firstName: string;
  lastName: string;
  username: string;
  email: string;
  password: string;
  phoneNumber: string;
  role: UserRole;
  profilePicture?: string;
  MapsLocation?: string;
  description?: string;
  details?: IUserDetails;
  reviews?: any[];
  rating?: number;
  refreshToken?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

// Définition du schéma Mongoose
const UserSchema: Schema = new Schema(
  {
    firstName: { type: String, required: true },
    lastName: { type: String, required: true },
    username: { type: String, required: true, unique: true, trim: true },
    email: { type: String, required: true, unique: true, trim: true, lowercase: true, match: /^\S+@\S+\.\S+$/ },
    password: { type: String, required: true, select: false },
    phoneNumber: { type: String, required: true, unique: true, trim: true },
    role: { type: String, enum: Object.values(UserRole), required: true },
    profilePicture: { type: String, default: null },
    MapsLocation: { type: String, default: null },
    description: { type: String, default: null, trim: true },
    details: {
      services: { type: [String], default: [] },
      workingHours: [
        {
          day: { type: String, required: true },
          start: { type: String, required: true },
          end: { type: String, required: true }
        }
      ]
    },
    reviews: { type: Array, default: [] },
    rating: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
      set: (value: number) => parseFloat(value.toFixed(2))
    },
    refreshToken: { type: String, default: null, select: false },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model<IUser>("User", UserSchema);
