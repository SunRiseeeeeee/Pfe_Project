import mongoose, { Schema, Document } from "mongoose";

// Interface TypeScript pour un Animal
export interface IAnimal extends Document {
  name: string;
  picture?: string;
  breed?: string;
  gender?: "Male" | "Female";
  birthDate?: Date;
  owner: mongoose.Schema.Types.ObjectId;
}

// Définition du schéma Mongoose
const AnimalSchema: Schema = new Schema({
  name: { type: String, required: true },
  picture: { type: String, default: null },
  breed: { type: String },
  gender: {
    type: String,
    enum: ["Male", "Female"],
    default: null,
  },
  birthDate: { type: Date },
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
  },
});

// ✅ Champ virtuel pour l'âge (en années et mois)
AnimalSchema.virtual("age").get(function (this: IAnimal) {
  if (!this.birthDate) return null;

  const now = new Date();
  const birth = new Date(this.birthDate);

  let years = now.getFullYear() - birth.getFullYear();
  let months = now.getMonth() - birth.getMonth();

  if (months < 0) {
    years--;
    months += 12;
  }

  return { years, months };
});

// ✅ Inclure les champs virtuels dans le JSON
AnimalSchema.set("toJSON", { virtuals: true });
AnimalSchema.set("toObject", { virtuals: true });

export default mongoose.model<IAnimal>("Animal", AnimalSchema);
