import mongoose, { Schema, Document } from "mongoose";

export enum AppointmentType {
  DOMICILE = "domicile",
  CABINET = "cabinet",
}

export enum AppointmentStatus {
  PENDING = "pending",
  ACCEPTED = "accepted",
  REJECTED = "rejected",
}

export interface IAppointment extends Document {
  date: Date;
  clientId: string; // ID du client
  clientFirstName: string;
  clientLastName: string;
  animalName: string;
  type: AppointmentType;
  status: AppointmentStatus;
  veterinaire: string; // ID du vétérinaire
  veterinaireFirstName: string;
  veterinaireLastName: string;
  createdAt: Date;
}

const AppointmentSchema: Schema = new Schema({
  date: { type: Date, required: true },
  clientId: { type: String, required: true },
  clientFirstName: { type: String, required: true }, // Prénom du client
  clientLastName: { type: String, required: true },  // Nom du client
  animalName: { type: String, required: true },
  type: {
    type: String,
    enum: Object.values(AppointmentType),
    required: true,
  },
  status: {
    type: String,
    enum: Object.values(AppointmentStatus),
    default: AppointmentStatus.PENDING,
  },
  veterinaire: { type: String, required: true }, // ID du vétérinaire
  veterinaireFirstName: { type: String, required: true }, // Prénom du vétérinaire
  veterinaireLastName: { type: String, required: true }, // Nom du vétérinaire
  createdAt: { type: Date, default: Date.now },
});

export default mongoose.model<IAppointment>("Appointment", AppointmentSchema);
