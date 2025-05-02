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
  clientId: mongoose.Types.ObjectId;     // modifié
  veterinaireId: mongoose.Types.ObjectId; // modifié
  animalType: string;
  type: AppointmentType;
  status: AppointmentStatus;
  services?: string[];
  createdAt: Date;
  updatedAt: Date;
}

const AppointmentSchema: Schema = new Schema(
  {
    date: { type: Date, required: true },
    clientId: { type: Schema.Types.ObjectId, ref: "User", required: true },         // modifié
    veterinaireId: { type: Schema.Types.ObjectId, ref: "User", required: true },    // modifié
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
