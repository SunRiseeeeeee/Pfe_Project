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
  clientId: string;
  veterinaireId: string;
  animalType: string; // libre, pas limité à une énumération
  type: AppointmentType;
  status: AppointmentStatus;
  createdAt: Date;
}

const AppointmentSchema: Schema = new Schema({
  date: { type: Date, required: true },
  clientId: { type: String, required: true },
  veterinaireId: { type: String, required: true },
  animalType: { type: String, required: true }, // <- libre
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
  createdAt: { type: Date, default: Date.now },
});

export default mongoose.model<IAppointment>("Appointment", AppointmentSchema);
