import { Schema, model, Document } from 'mongoose';

export enum UserRole {
  CLIENT = "client",
  VETERINAIRE = "veterinaire",
  SECRETAIRE = "secretaire",
  ADMIN = "admin"
}

export interface IUser extends Document {
  username: string;
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phoneNumber: string;
  role: UserRole;
  profilePicture?: string;
  location?: string;
  details?: {
    specialty?: string;
    workingHours?: string;
  };
  reviews?: string[];  // Ajout de la propriété reviews ici
}

const userSchema = new Schema<IUser>({
  username: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  firstName: { type: String, required: true },
  lastName: { type: String, required: true },
  phoneNumber: { type: String, required: true },
  role: { type: String, enum: Object.values(UserRole), required: true },
  profilePicture: { type: String },
  location: { type: String },
  details: {
    specialty: { type: String },
    workingHours: { type: String },
  },
  reviews: { type: [String], default: [] },  // Ajout de la propriété reviews avec un tableau vide par défaut
});

const User = model<IUser>("User", userSchema);

export default User;
