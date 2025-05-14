import mongoose, { Schema, Document, Types } from "mongoose";
import { IAnimal } from "./Animal";

// Interfaces pour les sous-documents
interface IVaccination {
  name: string;
  date: Date;
  nextDueDate?: Date;
  notes?: string;
}

interface ITreatment {
  name: string;
  startDate: Date;
  endDate?: Date;
  dosage?: string;
  frequency?: string;
  notes?: string;
}

interface IExamination {
  date: Date;
  type: string;
  results?: string;
  notes?: string;
}

interface IAppointmentRecord {
  appointmentDate: Date;
  diagnosis?: string;
}

// Interface principale pour le modèle Mongoose
export interface IAnimalFiche extends Document {
  animal: Types.ObjectId | IAnimal;
  veterinarian: Types.ObjectId;
  client: Types.ObjectId;
  creationDate: Date;
  lastUpdate: Date;
  weight?: number;
  height?: number;
  temperature?: number;
  vaccinations?: IVaccination[];
  treatments?: ITreatment[];
  examinations?: IExamination[];
  appointments?: IAppointmentRecord[];
  allergies?: string[];
  diet?: string;
  behaviorNotes?: string;
  medicalHistory?: string;
  recommendedNextVisit?: Date;
  generalNotes?: string;
}

// Définition du schéma Mongoose
const AnimalFicheSchema: Schema = new Schema(
  {
    animal: {
      type: Schema.Types.ObjectId,
      ref: "Animal",
      required: true,
    },
    veterinarian: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    client: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    creationDate: {
      type: Date,
      default: Date.now,
    },
    lastUpdate: {
      type: Date,
      default: Date.now,
    },
    weight: { type: Number },
    height: { type: Number },
    temperature: { type: Number },

    vaccinations: [
      {
        name: { type: String, required: true },
        date: { type: Date, required: true },
        nextDueDate: { type: Date },
        notes: { type: String },
      },
    ],

    treatments: [
      {
        name: { type: String, required: true },
        startDate: { type: Date, required: true },
        endDate: { type: Date },
        dosage: { type: String },
        frequency: { type: String },
        notes: { type: String },
      },
    ],

    examinations: [
      {
        date: { type: Date, required: true },
        type: { type: String, required: true },
        results: { type: String },
        notes: { type: String },
      },
    ],
                                                                            
    appointments: [
      {
        appointmentDate: { type: Date, required: true },
        diagnosis: { type: String },
      },
    ],

    allergies: [{ type: String }],
    diet: { type: String },
    behaviorNotes: { type: String },
    medicalHistory: { type: String },
    recommendedNextVisit: { type: Date },
    generalNotes: { type: String },
  },
  {
    timestamps: { createdAt: "creationDate", updatedAt: "lastUpdate" },
  }
);

// Middleware pour mettre à jour `lastUpdate` à chaque modification
AnimalFicheSchema.pre<IAnimalFiche>("save", function (next) {
  this.lastUpdate = new Date();
  next();
});

export default mongoose.model<IAnimalFiche>("AnimalFiche", AnimalFicheSchema);
