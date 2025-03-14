import mongoose, { Schema, Document } from "mongoose";

// Interface TypeScript pour un post
export interface IPost extends Document {
  photo: string; // Photo du post
  description: string; // Description du post
  comments: mongoose.Types.ObjectId[]; // Références vers les commentaires
  likes: number; // Nombre de likes
  createdAt: Date; // Date de création du post
  createdBy: mongoose.Types.ObjectId; // Référence vers l'utilisateur (User, Veterinarian ou Secretary)
}

// Définition du schéma Mongoose
const PostSchema: Schema = new Schema({
  photo: { type: String, required: true }, // Photo du post
  description: { type: String, required: true }, // Description du post
  comments: [{ type: Schema.Types.ObjectId, ref: "Comment" }], // Références vers les commentaires
  likes: { type: Number, default: 0 }, // Nombre de likes, par défaut 0
  createdAt: { type: Date, default: Date.now }, // Date de création du post
  createdBy: { type: Schema.Types.ObjectId, refPath: "createdByModel", required: true }, // Référence vers l'utilisateur
  createdByModel: { type: String, required: true, enum: ["User", "Veterinarian", "Secretary"] }, // Modèle de l'utilisateur
});

export default mongoose.model<IPost>("Post", PostSchema);