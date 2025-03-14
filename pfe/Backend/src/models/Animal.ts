import mongoose, { Schema, Document } from "mongoose";



// Interface TypeScript pour un utilisateur
export interface IAnimal extends Document {
  Name: string;
  Picture?: string;
  Breed?: string;
  Gender?: string;
  BirthDate?: string;
  details?: {
    Weight?: string;
    Vaccinations?: string;
    MedicalHistory?: string;
    OngoingTreatments?: string;
    ChronicProblems?: string;
    SurgicalHistory?: string;   
    LastAppointmentDate?: string;
  };
}

// Définition du schéma Mongoose
const AnimalSchema: Schema = new Schema({
  firstName: { type: String, required: true },
  Picture: { type: String, default: null },
  Breed: { type: String },
  Gender: { type: String },
  BirthDate: { type: String },
  
  details: {
    Weight: { type: String, default: null },
    Vaccinations: { type: String, default: null },
    MedicalHistory: { type: String, default: null },
    OngoingTreatments: { type: String, default: null },
    ChronicProblems: { type: String, default: null },
    SurgicalHistory: { type: String, default: null },
    LastAppointmentDate: { type: String, default: null },
  },
});

export default mongoose.model<IAnimal>("User", AnimalSchema);
