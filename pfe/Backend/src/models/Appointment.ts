import mongoose, { Schema, Document } from "mongoose";

export enum AppointmentType {
  DOMICILE = "household",
  CABINET = "clinic",
}

export enum AppointmentStatus {
  PENDING = "pending",
  ACCEPTED = "accepted",
  REJECTED = "rejected",
}

export interface IAppointment extends Document {
  date: Date;
  clientId: mongoose.Types.ObjectId;
  veterinaireId: mongoose.Types.ObjectId;
  animalId: mongoose.Types.ObjectId;
  type: AppointmentType;
  status: AppointmentStatus;
  services: string[];
  caseDescription?: string;
  notificationSent?: boolean;
  createdAt: Date;
  updatedAt: Date;
}
const AppointmentSchema: Schema<IAppointment> = new Schema(
  {
    date: { type: Date, required: true },
    clientId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    veterinaireId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    animalId: { type: Schema.Types.ObjectId, ref: "Animal", required: true },
    caseDescription: { type: String, default: "" },
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
    },
    notificationSent: { type: Boolean, default: false },
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
    toObject: {
      virtuals: true,
      transform(doc, ret) {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

export default mongoose.model<IAppointment>("Appointment", AppointmentSchema);
