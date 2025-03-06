import mongoose, { Schema, Document } from "mongoose";

export enum UserRole {
  CLIENT = "client",
  VETERINAIRE = "veterinaire",
  SECRETAIRE = "secretaire",
  ADMIN = "admin",
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
  location?: string;
  details?: {
    specialty?: string;
    workingHours?: string;
  };
  reviews?: any[];
  refreshToken?: string | null; // ✅ Ajout de refreshToken
}

// Définition du schéma Mongoose
const UserSchema: Schema = new Schema({
  firstName: { type: String, required: true },
  lastName: { type: String, required: true },
  username: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  phoneNumber: { type: String, required: true, unique: true },
  role: { type: String, enum: Object.values(UserRole), required: true },
  profilePicture: { type: String, default: null },
  location: { type: String, default: null },
  details: {
    specialty: { type: String, default: null },
    workingHours: { type: String, default: null },
  },
  reviews: { type: Array, default: [] },
  refreshToken: { type: String, default: null }, // ✅ Ajout du refreshToken dans Mongoose
});

export default mongoose.model<IUser>("User", UserSchema);
