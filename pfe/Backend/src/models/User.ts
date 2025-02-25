import mongoose, { Schema, Document } from "mongoose";

export enum UserRole {
  CLIENT = "client",
  VETERINAIRE = "veterinaire",
  SECRETAIRE = "secretaire",
}

export interface IUser extends Document {
  username: string;
  password: string;
  role: UserRole;
}

const UserSchema: Schema = new Schema({
    username: { type: String, required: true, unique: true },
    email: {
      type: String,
      unique: true,
      required: true,
      match: /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/, // Validation regex
    }
    ,
    password: { type: String, required: true },
    role: { type: String, enum: Object.values(UserRole), required: true },
  });
  

export default mongoose.model<IUser>("User", UserSchema);
