import { Request, Response, NextFunction } from "express";
import mongoose from "mongoose";
import Appointment, { AppointmentStatus, AppointmentType } from "../models/Appointment";
import User, { UserRole } from "../models/User";

import { UserTokenPayload } from "../middlewares/authMiddleware";

declare module "express" {
  interface Request {
    user?: UserTokenPayload;
  }
}

const sendResponse = (
  res: Response,
  status: number,
  data: object,
  message?: string
): void => {
  res.status(status).json(message ? { message, ...data } : data);
};

export const createAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { date, animalType, type, services, veterinaireId } = req.body;
    const user = req.user;

    if (!user || user.role !== UserRole.CLIENT) {
      return sendResponse(res, 403, {}, "Accès interdit : seul un client peut créer un rendez-vous.");
    }

    if (!date || !animalType || !type) {
      return sendResponse(res, 400, {}, "Les champs 'date', 'animalType' et 'type' sont obligatoires.");
    }

    if (!Object.values(AppointmentType).includes(type)) {
      return sendResponse(res, 400, {}, `Type de rendez-vous invalide. Autorisés : ${Object.values(AppointmentType).join(", ")}`);
    }

    const client = await User.findById(user.id);
    if (!client) {
      return sendResponse(res, 404, {}, "Client non trouvé.");
    }

    let veterinaire = null;
    if (veterinaireId) {
      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        return sendResponse(res, 400, {}, "ID vétérinaire invalide");
      }
      veterinaire = await User.findOne({ _id: veterinaireId, role: UserRole.VETERINAIRE });
    } else {
      veterinaire = await User.findOne({ role: UserRole.VETERINAIRE });
    }

    if (!veterinaire) {
      return sendResponse(res, 404, {}, "Vétérinaire non trouvé.");
    }

    const appointment = new Appointment({
      clientId: user.id,
      veterinaireId: veterinaire._id,
      date: new Date(date),
      animalType,
      type,
      status: AppointmentStatus.PENDING,
      services: Array.isArray(services) ? services : [],
    });

    await appointment.save();

    sendResponse(res, 201, { appointment }, "Rendez-vous créé avec succès.");
  } catch (error) {
    console.error("[createAppointment] Error:", error);
    next(error);
  }
};

export const getAppointmentById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    // Validation de l'ID du rendez-vous
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }

    // Recherche du rendez-vous avec peuplement des informations du vétérinaire et du client
    const appointment = await Appointment.findById(id)
      .populate("veterinaireId", "-password -refreshToken")  // Exclure les champs sensibles
      .populate("clientId", "-password -refreshToken");      // Exclure les champs sensibles

    // Si le rendez-vous n'est pas trouvé
    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
    }

    // Retourner le rendez-vous avec les informations du vétérinaire et du client
    sendResponse(res, 200, { appointment });
  } catch (error) {
    console.error("[getAppointmentById] Error:", error);
    next(error);
  }
};


export const acceptAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }

    const appointment = await Appointment.findByIdAndUpdate(
      id,
      { status: AppointmentStatus.ACCEPTED },
      { new: true }
    );

    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
    }

    sendResponse(res, 200, { appointment });
  } catch (error) {
    console.error("[acceptAppointment] Error:", error);
    next(error);
  }
};

export const rejectAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }

    const appointment = await Appointment.findByIdAndUpdate(
      id,
      { status: AppointmentStatus.REJECTED },
      { new: true }
    );

    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
    }

    sendResponse(res, 200, { appointment });
  } catch (error) {
    console.error("[rejectAppointment] Error:", error);
    next(error);
  }
};

export const getAppointmentsByClient = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { clientId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(clientId)) {
      return sendResponse(res, 400, {}, "ID client invalide");
    }

    const appointments = await Appointment.find({ clientId }).populate("veterinaireId", "-password -refreshToken");

    sendResponse(res, 200, { appointments });
  } catch (error) {
    console.error("[getAppointmentsByClient] Error:", error);
    next(error);
  }
};

// Récupérer les rendez-vous d'un vétérinaire
export const getAppointmentsByVeterinaire = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { veterinaire } = req.params;

    // Validation de l'ID
    if (!mongoose.Types.ObjectId.isValid(veterinaire)) {
      sendResponse(res, 400, {}, "ID vétérinaire invalide");
      return;
    }

    // Recherche du vétérinaire
    const veterinaireRecord = await User.findById(veterinaire);
    if (!veterinaireRecord) {
      sendResponse(res, 404, {}, "Vétérinaire non trouvé");
      return;
    }

    // Récupération de tous les rendez-vous pour ce vétérinaire
    const appointments = await Appointment.find({ veterinaireId: veterinaire })
                                          .populate("clientId", "-password -refreshToken");
    
    if (!appointments.length) {
      sendResponse(res, 404, {}, "Aucun rendez-vous trouvé pour ce vétérinaire.");
      return;
    }

    sendResponse(res, 200, { appointments });
  } catch (error) {
    console.error("[getAppointmentsByVeterinaire] Error:", error);
    next(error);
  }
};


export const deleteAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }

    const appointment = await Appointment.findById(id);
    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
    }

    await Appointment.findByIdAndDelete(id);
    sendResponse(res, 200, {}, "Rendez-vous supprimé avec succès.");
  } catch (error) {
    console.error("[deleteAppointment] Error:", error);
    next(error);
  }
};

export const updateAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const updatedData = req.body;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }

    const appointment = await Appointment.findById(id);
    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé");
    }

    const protectedFields = ["clientId", "veterinaireId", "createdAt", "updatedAt"];
    protectedFields.forEach(field => delete updatedData[field]);

    const updatedAppointment = await Appointment.findByIdAndUpdate(id, updatedData, { new: true, runValidators: true });

    if (!updatedAppointment) {
      return sendResponse(res, 404, {}, "Erreur lors de la mise à jour");
    }

    sendResponse(res, 200, {
      id: updatedAppointment._id,
      date: updatedAppointment.date,
      animalType: updatedAppointment.animalType,
      type: updatedAppointment.type,
      status: updatedAppointment.status,
      services: updatedAppointment.services
    });
  } catch (error) {
    console.error("[updateAppointment] Error:", error);
    next(error);
  }
};
