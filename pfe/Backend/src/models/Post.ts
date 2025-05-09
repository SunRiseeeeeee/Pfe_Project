import mongoose, { Schema, Document, Types } from "mongoose";

// Interface TypeScript pour un post
export interface IPost extends Document {
  photo: string; // Photo du post
  description: string; // Description du post
  createdAt: Date; // Date de création du post (gérée automatiquement avec timestamps)
  updatedAt: Date; // Date de dernière modification (gérée automatiquement avec timestamps)
  createdBy: mongoose.Types.ObjectId; // Référence vers l'utilisateur (User, Veterinarian)
  createdByModel: "User" | "Veterinarian"; // Modèle de l'utilisateur
  veterinaireId?: Types.ObjectId; // ID du vétérinaire si le post est créé par un vétérinaire
}

// Définition du schéma Mongoose
const PostSchema: Schema = new Schema({
  photo: { type: String, required: true }, // Photo du post
  description: { type: String, required: true }, // Description du post
  createdBy: { 
    type: Schema.Types.ObjectId, 
    refPath: 'createdByModel', 
    required: true 
  },
  createdByModel: { 
    type: String, 
    required: true, 
    enum: ["Veterinarian"], // Permet de définir soit User, soit Veterinarian
  },
  veterinaireId: { 
    type: Schema.Types.ObjectId, 
    ref: 'Veterinarian', // Le vétérinaire peut être lié à un utilisateur vétérinaire
    required: false 
  },
}, { timestamps: true }); // Active la gestion automatique des dates createdAt et updatedAt

export default mongoose.model<IPost>("Post", PostSchema);
