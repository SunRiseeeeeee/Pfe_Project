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
  refreshToken?: string | null; // Token de rafraîchissement pour JWT
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
    password: { type: String, required: true, select: false }, // `select: false` empêche l'affichage du mot de passe par défaut
    phoneNumber: { type: String, required: true, unique: true, trim: true },
    role: { type: String, enum: Object.values(UserRole), required: true },
    profilePicture: { type: String, default: null },
    location: { type: String, default: null },
    details: {
      specialty: { type: String, default: null },
      workingHours: { type: String, default: null },
    },
    reviews: { type: Array, default: [] },
    refreshToken: { type: String, default: null, select: false }, // `select: false` pour ne pas exposer le refreshToken
  },
  {
    timestamps: true, // Ajoute automatiquement createdAt et updatedAt
  }
);

export default mongoose.model<IUser>("User", UserSchema);
