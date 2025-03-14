import mongoose, { Schema, Document } from "mongoose";

export enum AppointmentType {
  DOMICILE = "domicile",
  CABINET = "cabinet",
}

// Interface TypeScript pour un rendez-vous
export interface IAppointment extends Document {
  date: Date; // Date et heure du rendez-vous
  clientName: string; // Nom du client
  animalName: string; // Nom de l'animal
  type: AppointmentType; // Type de rendez-vous (domicile ou cabinet)
  createdAt: Date; // Date et heure de la prise de rendez-vous
}

// Définition du schéma Mongoose
const AppointmentSchema: Schema = new Schema({
  date: { type: Date, required: true }, // Date et heure du rendez-vous
  clientName: { type: String, required: true }, // Nom du client
  animalName: { type: String, required: true }, // Nom de l'animal
  type: {
    type: String,
    enum: Object.values(AppointmentType), // Validation du type de rendez-vous
    required: true,
  },
  createdAt: { type: Date, default: Date.now }, // Date et heure de la prise de rendez-vous
});

export default mongoose.model<IAppointment>("Appointment", AppointmentSchema);