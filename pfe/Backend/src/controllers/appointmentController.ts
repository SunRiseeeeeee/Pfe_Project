import { Request, Response, NextFunction } from "express";
import mongoose from "mongoose";
import Appointment, { AppointmentStatus, AppointmentType } from "../models/Appointment";
import User, { UserRole } from "../models/User";

// Utilisez l'interface existante depuis votre authMiddleware
import { UserTokenPayload } from "../middlewares/authMiddleware";

// Extension cohérente du type Request
declare module "express" {
  interface Request {
    user?: UserTokenPayload;
  }
}

// Helper pour les réponses JSON
const sendResponse = (
  res: Response,
  status: number,
  data: object,
  message?: string
): void => {
  if (message) {
    res.status(status).json({ message, ...data });
  } else {
    res.status(status).json(data);
  }
};

// Créer un rendez-vous
export const createAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { date, animalType, type, services, veterinaireId } = req.body;
    const user = req.user;

    if (!user || user.role !== UserRole.CLIENT) {
      sendResponse(res, 403, {}, "Accès interdit : seul un client peut créer un rendez-vous.");
      return;
    }

    // Validation des champs obligatoires
    if (!date || !animalType || !type) {
      sendResponse(res, 400, {}, "Les champs 'date', 'animalType' et 'type' sont obligatoires.");
      return;
    }

    if (!Object.values(AppointmentType).includes(type)) {
      sendResponse(
        res,
        400,
        {}, 
        `Type de rendez-vous invalide. Autorisés : ${Object.values(AppointmentType).join(", ")}`
      );
      return;
    }

    // Vérification du client
    const client = await User.findById(user.id);
    if (!client) {
      sendResponse(res, 404, {}, "Client non trouvé.");
      return;
    }

    // Recherche du vétérinaire
    let veterinaire = null;
    if (veterinaireId) {
      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        sendResponse(res, 400, {}, "ID vétérinaire invalide");
        return;
      }
      veterinaire = await User.findOne({ _id: veterinaireId, role: UserRole.VETERINAIRE });
    } else {
      // Sélection automatique d'un vétérinaire disponible
      veterinaire = await User.findOne({ role: UserRole.VETERINAIRE });
    }

    if (!veterinaire) {
      sendResponse(res, 404, {}, "Vétérinaire non trouvé.");
      return;
    }

    // Création du rendez-vous
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

    sendResponse(
      res,
      201,
      { appointment },
      "Rendez-vous créé avec succès."
    );
  } catch (error) {
    console.error("[createAppointment] Error:", error);
    next(error);
  }
};

// Récupérer un rendez-vous par ID
export const getAppointmentById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      sendResponse(res, 400, {}, "ID de rendez-vous invalide");
      return;
    }

    const appointment = await Appointment.findById(id);
    if (!appointment) {
      sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
      return;
    }

    sendResponse(res, 200, appointment);
  } catch (error) {
    console.error("[getAppointmentById] Error:", error);
    next(error);
  }
};

// Accepter un rendez-vous
export const acceptAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      sendResponse(res, 400, {}, "ID de rendez-vous invalide");
      return;
    }

    const appointment = await Appointment.findByIdAndUpdate(
      id,
      { status: AppointmentStatus.ACCEPTED },
      { new: true }
    );

    if (!appointment) {
      sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
      return;
    }

    sendResponse(res, 200, appointment);
  } catch (error) {
    console.error("[acceptAppointment] Error:", error);
    next(error);
  }
};

// Refuser un rendez-vous
export const rejectAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      sendResponse(res, 400, {}, "ID de rendez-vous invalide");
      return;
    }

    const appointment = await Appointment.findByIdAndUpdate(
      id,
      { status: AppointmentStatus.REJECTED },
      { new: true }
    );

    if (!appointment) {
      sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
      return;
    }

    sendResponse(res, 200, appointment);
  } catch (error) {
    console.error("[rejectAppointment] Error:", error);
    next(error);
  }
};

// Récupérer les rendez-vous d'un client
export const getAppointmentsByClient = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { clientId } = req.params;

    if (!req.user) {
      sendResponse(res, 401, {}, "Non authentifié.");
      return;
    }

    if (req.user.role !== UserRole.CLIENT || String(req.user.id) !== String(clientId)) {
      sendResponse(res, 403, {}, "Non autorisé à accéder à ces rendez-vous.");
      return;
    }

    if (!mongoose.Types.ObjectId.isValid(clientId)) {
      sendResponse(res, 400, {}, "ID client invalide");
      return;
    }

    const appointments = await Appointment.find({ clientId });

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
    const { veterinaireId } = req.params;
    const user = req.user;

    if (!user || (user.role !== UserRole.VETERINAIRE && user.role !== UserRole.ADMIN)) {
      sendResponse(res, 403, {}, "Accès non autorisé.");
      return;
    }

    if (user.role === UserRole.VETERINAIRE && String(user.id) !== String(veterinaireId)) {
      sendResponse(res, 403, {}, "Vous ne pouvez voir que vos propres rendez-vous.");
      return;
    }

    if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
      sendResponse(res, 400, {}, "ID vétérinaire invalide");
      return;
    }

    const appointments = await Appointment.find({ veterinaireId });

    sendResponse(res, 200, { appointments });
  } catch (error) {
    console.error("[getAppointmentsByVeterinaire] Error:", error);
    next(error);
  }
};

// Supprimer un rendez-vous
export const deleteAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const user = req.user;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      sendResponse(res, 400, {}, "ID de rendez-vous invalide");
      return;
    }

    const appointment = await Appointment.findById(id);
    if (!appointment) {
      sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
      return;
    }

    // Seul le client ou l'admin peut supprimer
    if (
      user?.role !== UserRole.ADMIN && 
      String(user?.id) !== String(appointment.clientId)
    ) {
      sendResponse(res, 403, {}, "Non autorisé à supprimer ce rendez-vous.");
      return;
    }

    await Appointment.findByIdAndDelete(id);
    sendResponse(res, 200, {}, "Rendez-vous supprimé avec succès.");
  } catch (error) {
    console.error("[deleteAppointment] Error:", error);
    next(error);
  }
};

// Mettre à jour un rendez-vous
export const updateAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const updatedData = req.body;
    const user = req.user;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      sendResponse(res, 400, {}, "ID de rendez-vous invalide");
      return;
    }

    const appointment = await Appointment.findById(id);
    if (!appointment) {
      sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
      return;
    }

    // Vérification des permissions
    if (
      user?.role !== UserRole.ADMIN && 
      String(user?.id) !== String(appointment.clientId) && 
      String(user?.id) !== String(appointment.veterinaireId)
    ) {
      sendResponse(res, 403, {}, "Non autorisé à modifier ce rendez-vous.");
      return;
    }

    // Validation des données
    if (updatedData.type && !Object.values(AppointmentType).includes(updatedData.type)) {
      sendResponse(
        res,
        400,
        {},
        `Type de rendez-vous invalide. Autorisés : ${Object.values(AppointmentType).join(", ")}`
      );
      return;
    }

    const updatedAppointment = await Appointment.findByIdAndUpdate(
      id,
      updatedData,
      { new: true }
    );

    sendResponse(res, 200, updatedAppointment!);
  } catch (error) {
    console.error("[updateAppointment] Error:", error);
    next(error);
  }
};