import mongoose, { Schema, Document, Types } from "mongoose";
import { IAnimal } from "./Animal";

// Interface pour les vaccinations
interface IVaccination {
  name: string;
  date: Date;
  nextDueDate?: Date;
  notes?: string;
}

// Interface pour les traitements
interface ITreatment {
  name: string;
  startDate: Date;
  endDate?: Date;
  dosage?: string;
  frequency?: string;
  notes?: string;
}

// Interface pour les examens
interface IExamination {
  date: Date;
  type: string;
  results?: string;
  notes?: string;
}

// Interface pour les rendez-vous
interface IAppointmentRecord {
  appointmentDate: Date;
  diagnosis?: string;
}

// Interface TypeScript pour une Fiche Animalière
export interface IAnimalFiche extends Document {
  animalId: Types.ObjectId | IAnimal;
  veterinarian: Types.ObjectId;
  creationDate: Date;
  lastUpdate: Date;
  weight?: number;
  height?: number;
  temperature?: number;
  vaccinations?: IVaccination[];
  treatments?: ITreatment[];
  examinations?: IExamination[];
  allergies?: string[];
  diet?: string;
  behaviorNotes?: string;
  medicalHistory?: string;
  recommendedNextVisit?: Date;
  generalNotes?: string;
  appointments?: IAppointmentRecord[];
}

// Définition du schéma Mongoose
const AnimalFicheSchema: Schema = new Schema({
  animal: { 
    type: Schema.Types.ObjectId, 
    ref: "Animal", 
    required: true 
  },
  veterinarian: { 
    type: Schema.Types.ObjectId, 
    ref: "User", 
    required: true 
  },
  creationDate: { 
    type: Date, 
    default: Date.now 
  },
  lastUpdate: { 
    type: Date, 
    default: Date.now 
  },
  weight: { type: Number },
  height: { type: Number },
  temperature: { type: Number },
  vaccinations: [{
    name: { type: String, required: true },
    date: { type: Date, required: true },
    nextDueDate: { type: Date },
    notes: { type: String }
  }],
  treatments: [{
    name: { type: String, required: true },
    startDate: { type: Date, required: true },
    endDate: { type: Date },
    dosage: { type: String },
    frequency: { type: String },
    notes: { type: String }
  }],
  examinations: [{
    date: { type: Date, required: true },
    type: { type: String, required: true },
    results: { type: String },
    notes: { type: String }
  }],
  appointments: [{
    appointmentDate: { type: Date, required: true },
    diagnosis: { type: String }
  }],
  allergies: [{ type: String }],
  diet: { type: String },
  behaviorNotes: { type: String },
  medicalHistory: { type: String },
  recommendedNextVisit: { type: Date },
  generalNotes: { type: String }
});

// Middleware pour mettre à jour la date de dernière modification
AnimalFicheSchema.pre<IAnimalFiche>("save", function(next) {
  this.lastUpdate = new Date();
  next();
});

export default mongoose.model<IAnimalFiche>("AnimalFiche", AnimalFicheSchema);
