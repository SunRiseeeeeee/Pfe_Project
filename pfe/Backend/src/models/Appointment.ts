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
  animalType: string;
  type: AppointmentType;
  status: AppointmentStatus;
  services?: string[];          // services associés au rendez-vous
  createdAt: Date;
  updatedAt: Date;
}

const AppointmentSchema: Schema = new Schema(
  {
    date: { type: Date, required: true },
    clientId: { type: String, required: true },
    veterinaireId: { type: String, required: true },
    animalType: { type: String, required: true },
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
    services: {
      type: [String],
      default: [],
      description: "Liste des services demandés lors du rendez-vous",
    },
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
    toObject: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

export default mongoose.model<IAppointment>("Appointment", AppointmentSchema);
