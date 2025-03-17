import mongoose, { Schema, Document } from "mongoose";

// Interface TypeScript pour un Animal
export interface IAnimal extends Document {
  name: string; // Nom de l'animal
  picture?: string; // Photo de l'animal (optionnelle)
  breed?: string; // Race de l'animal (optionnelle)
  gender?: "Male" | "Female"; // Genre de l'animal (optionnel)
  birthDate?: Date; // Date de naissance de l'animal (optionnelle)
  owner: mongoose.Schema.Types.ObjectId; // Référence à l'utilisateur propriétaire
}

// Définition du schéma Mongoose
const AnimalSchema: Schema = new Schema({
  name: { type: String, required: true }, // Nom de l'animal (obligatoire)
  picture: { type: String, default: null }, // Photo de l'animal (optionnelle)
  breed: { type: String }, // Race de l'animal (optionnelle)
  gender: { 
    type: String, 
    enum: ["Male", "Female"], // Restreint les valeurs à "Male" ou "Female"
    default: null, 
  }, // Genre de l'animal (optionnel)
  birthDate: { type: Date }, // Date de naissance de l'animal (optionnelle)
  owner: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "User", // Référence à un modèle "User"
    required: true, 
  }, // Référence à l'utilisateur propriétaire (obligatoire)
});

// Création du modèle Mongoose
export default mongoose.model<IAnimal>("Animal", AnimalSchema);