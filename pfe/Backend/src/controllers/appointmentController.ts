import { Request, Response, NextFunction, RequestHandler } from "express";
import mongoose from "mongoose";
import Appointment, { AppointmentStatus, AppointmentType, IAppointment } from "../models/Appointment";
import User, { UserRole } from "../models/User";
import { UserTokenPayload } from "../middlewares/authMiddleware";
import Animal from "../models/Animal";

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

// Créer un nouveau rendez-vous
export const createAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { date, animalId, type, services, veterinaireId, caseDescription } = req.body;
    const user = req.user;

    // Vérification de l'autorisation
    if (!user || user.role !== UserRole.CLIENT) {
      return sendResponse(res, 403, {}, "Accès interdit : seul un client peut créer un rendez-vous.");
    }

    // Validation des champs requis
    if (!date || !animalId || !type) {
      return sendResponse(res, 400, {}, "Les champs 'date', 'animalId' et 'type' sont obligatoires.");
    }

    if (!mongoose.Types.ObjectId.isValid(animalId)) {
      return sendResponse(res, 400, {}, "ID de l'animal invalide.");
    }

    if (!Object.values(AppointmentType).includes(type)) {
      return sendResponse(
        res,
        400,
        {},
        `Type de rendez-vous invalide. Autorisés : ${Object.values(AppointmentType).join(", ")}`
      );
    }

    // Vérification de l'existence du client
    const client = await User.findById(user.id);
    if (!client) {
      return sendResponse(res, 404, {}, "Client non trouvé.");
    }

    // Vérification de la propriété de l'animal
    const animal = await Animal.findOne({ _id: animalId, owner: client._id });
    if (!animal) {
      return sendResponse(res, 404, {}, "Animal non trouvé ou n'appartient pas à ce client.");
    }

    // Sélection du vétérinaire
    let veterinaire = null;
    if (veterinaireId) {
      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        return sendResponse(res, 400, {}, "ID vétérinaire invalide.");
      }
      veterinaire = await User.findOne({ _id: veterinaireId, role: UserRole.VETERINAIRE });
    } else {
      veterinaire = await User.findOne({ role: UserRole.VETERINAIRE });
    }

    if (!veterinaire) {
      return sendResponse(res, 404, {}, "Vétérinaire non trouvé.");
    }

    // Vérification du créneau
    const appointmentDate = new Date(date);
    const windowStart = new Date(appointmentDate.getTime() - 20 * 60000);
    const windowEnd = new Date(appointmentDate.getTime() + 20 * 60000);

    const conflicting = await Appointment.find({
      veterinaireId: veterinaire._id,
      date: { $gte: windowStart, $lte: windowEnd },
      status: { $ne: AppointmentStatus.REJECTED }
    });

    if (conflicting.length) {
      return sendResponse(
        res,
        400,
        {},
        "Créneau indisponible. Il doit y avoir au moins 20 minutes entre deux rendez-vous."
      );
    }

    // Enregistrer le rendez-vous
    const appointment = new Appointment({
      clientId: client._id,
      veterinaireId: veterinaire._id,
      animalId,
      date: appointmentDate,
      type,
      status: AppointmentStatus.PENDING,
      services: Array.isArray(services) ? services : [],
      caseDescription: caseDescription || "",
    });

    await appointment.save();
    sendResponse(res, 201, { appointment }, "Rendez-vous créé avec succès.");
  } catch (error) {
    console.error("[createAppointment] Error:", error);
    next(error);
  }
};

// Détail pour un vétérinaire
export const getAppointmentForVeterinaireById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      res.status(400).json({ message: "ID de rendez-vous invalide" });
      return;
    }
    const appointment = await Appointment.findById(id)
      .populate("clientId", "-password -refreshToken")
      .populate("animalId");
    if (!appointment) {
      res.status(404).json({ message: "Rendez-vous non trouvé" });
      return;
    }
    res.status(200).json({ appointment });
  } catch (error) {
    console.error("[getAppointmentForVeterinaireById] Error:", error);
    next(error);
  }
};

// Détail pour un client
export const getAppointmentForClientById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { clientId, id } = req.params as { clientId: string; id: string };
    if (!mongoose.Types.ObjectId.isValid(id)) {
      res.status(400).json({ message: "ID de rendez-vous invalide" });
      return;
    }
    const appointment = await Appointment.findById(id)
      .populate("veterinaireId", "-password -refreshToken")
      .populate("animalId");
    if (!appointment) {
      res.status(404).json({ message: "Rendez-vous non trouvé" });
      return;
    }
    if (appointment.clientId.toString() !== clientId) {
      res.status(403).json({ message: "Accès interdit : vous n’êtes pas le client concerné." });
      return;
    }
    res.status(200).json({ appointment });
  } catch (error) {
    console.error("[getAppointmentForClientById] Error:", error);
    next(error);
  }
};

// Historique client
export const getAppointmentsByClient: RequestHandler<{ clientId: string }> =
  async (req, res, next) => {
    const { clientId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(clientId)) {
      res.status(400).json({ message: "ID de client invalide." });
      return;
    }
    try {
      const exists = await User.exists({ _id: clientId, role: UserRole.CLIENT });
      if (!exists) {
        res.status(404).json({ message: "Client non trouvé." });
        return;
      }
      const allAppointments = await Appointment.find({ clientId })
        .populate("veterinaireId", "-password -refreshToken")
        .populate("animalId")
        .lean<IAppointment[]>();
      const filtered = allAppointments
        .map(a => ({
          ...a,
          status: (a.status as string).trim().replace(/,$/, "")
        }))
        .filter(a =>
          a.status === AppointmentStatus.PENDING ||
          a.status === AppointmentStatus.ACCEPTED
        );
      filtered.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
      if (!filtered.length) {
        res.status(404).json({ message: "Aucun rendez-vous pending/accepted trouvé pour ce client." });
        return;
      }
      res.status(200).json({ appointments: filtered });
    } catch (err) {
      console.error("[getAppointmentsByClient] Error:", err);
      next(err);
    }
  };
// Historique vétérinaire
export const getAppointmentsByVeterinaire: RequestHandler<{ veterinaireId: string }> =
  async (req, res, next) => {
    const { veterinaireId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
      res.status(400).json({ message: "ID vétérinaire invalide." });
      return;
    }
    try {
      const exists = await User.exists({ _id: veterinaireId, role: UserRole.VETERINAIRE });
      if (!exists) {
        res.status(404).json({ message: "Vétérinaire non trouvé." });
        return;
      }
      const allAppointments = await Appointment.find({ veterinaireId })
        .populate("clientId", "-password -refreshToken")
        .populate("animalId")
        .lean<IAppointment[]>();
      const filtered = allAppointments
        .map(a => ({
          ...a,
          status: (a.status as string).trim().replace(/,$/, "")
        }))
        .filter(a =>
          a.status === AppointmentStatus.PENDING ||
          a.status === AppointmentStatus.ACCEPTED
        );
      filtered.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
      if (!filtered.length) {
        res.status(404).json({ message: "Aucun rendez-vous pending/accepted trouvé pour ce vétérinaire." });
        return;
      }
      res.status(200).json({ appointments: filtered });
    } catch (err) {
      console.error("[getAppointmentsByVeterinaire] Error:", err);
      next(err);
    }
  };

// Accepter, refuser, mettre à jour, supprimer (inchangés)
export const acceptAppointment = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }
    const appointment = await Appointment.findByIdAndUpdate(id, { status: AppointmentStatus.ACCEPTED }, { new: true });
    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
    }
    sendResponse(res, 200, { appointment });
  } catch (error) {
    console.error("[acceptAppointment] Error:", error);
    next(error);
  }
};

export const rejectAppointment = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }
    const appointment = await Appointment.findByIdAndUpdate(id, { status: AppointmentStatus.REJECTED }, { new: true });
    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé.");
    }
    sendResponse(res, 200, { appointment });
  } catch (error) {
    console.error("[rejectAppointment] Error:", error);
    next(error);
  }
};

export const deleteAppointment = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
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

export const updateAppointment = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { id } = req.params;
    const updatedData = { ...req.body };
    const user = req.user;

    // Vérifications initiales
    if (!user) {
      return sendResponse(res, 401, {}, "Utilisateur non authentifié");
    }
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }

    // Récupération du rendez-vous
    const appointment = await Appointment.findById(id);
    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé");
    }

    // Vérification des autorisations
    if (user.role !== UserRole.CLIENT || appointment.clientId.toString() !== user.id) {
      return sendResponse(res, 403, {}, "Accès interdit : vous ne pouvez pas modifier ce rendez-vous.");
    }

    // Vérification du statut
    if (appointment.status !== AppointmentStatus.PENDING) {
      return sendResponse(res, 403, {}, "Modification interdite : Le statut du rendez-vous n'est pas 'pending'.");
    }

    // Protection des champs sensibles
    const protectedFields = ["clientId", "veterinaireId", "createdAt", "updatedAt", "_id", "__v"];
    for (const field of protectedFields) {
      delete updatedData[field];
    }

    // Vérification de l'animal
    if (updatedData.animalId) {
      if (!mongoose.Types.ObjectId.isValid(updatedData.animalId)) {
        return sendResponse(res, 400, {}, "ID de l'animal invalide.");
      }
      const animalCheck = await Animal.findOne({ _id: updatedData.animalId, owner: user.id });
      if (!animalCheck) {
        return sendResponse(res, 403, {}, "Cet animal n'existe pas ou ne vous appartient pas.");
      }
    }

    // Vérification des conflits de rendez-vous (nouvelle implémentation)
    if (updatedData.date) {
      const newDate = new Date(updatedData.date);
      const minEndTime = new Date(newDate.getTime() + 20 * 60000); // +20 minutes
      
      const conflicting = await Appointment.find({
        _id: { $ne: id }, // Exclure le rendez-vous actuel
        $or: [
          { 
            date: { 
              $gte: newDate, 
              $lt: minEndTime 
            } 
          },
          {
            date: { 
              $lt: newDate, 
              $gte: new Date(newDate.getTime() - 20 * 60000) 
            }
          }
        ]
      });

      if (conflicting.length > 0) {
        return sendResponse(
          res,
          400,
          {},
          "Créneau indisponible. Il doit y avoir au moins 20 minutes entre deux rendez-vous."
        );
      }
    }

    // Mise à jour du rendez-vous
    const updatedAppointment = await Appointment.findByIdAndUpdate(
      id, 
      updatedData, 
      { new: true, runValidators: true }
    );

    if (!updatedAppointment) {
      return sendResponse(res, 500, {}, "Erreur lors de la mise à jour.");
    }

    // Réponse réussie
    sendResponse(res, 200, {
      id: updatedAppointment._id,
      date: updatedAppointment.date,
      animalId: updatedAppointment.animalId,
      type: updatedAppointment.type,
      status: updatedAppointment.status,
      services: updatedAppointment.services,
      caseDescription: updatedAppointment.caseDescription
    }, "Rendez-vous mis à jour avec succès.");

  } catch (error) {
    console.error("[updateAppointment] Error:", error);
    next(error);
  }
};
// Fonction pour récupérer la liste des clients avec un rendez-vous accepté chez un vétérinaire spécifique
export const getClientsWithAcceptedAppointmentsForVeterinaire = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { veterinaireId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
      return sendResponse(res, 400, {}, "ID de vétérinaire invalide.");
    }

    // Vérifier si le vétérinaire existe
    const veterinaireExists = await User.exists({ _id: veterinaireId, role: UserRole.VETERINAIRE });
    if (!veterinaireExists) {
      return sendResponse(res, 404, {}, "Vétérinaire non trouvé.");
    }

    // Récupérer les rendez-vous acceptés avec les informations des clients
    const appointments = await Appointment.find({
      veterinaireId,
      status: AppointmentStatus.ACCEPTED,
    }).populate("clientId", "firstName lastName email phoneNumber address profilePicture");

    // Extraire les clients sans doublons
    const uniqueClients = Array.from(
      new Map(
        appointments.map((a) => [a.clientId._id.toString(), a.clientId])
      ).values()
    );

    if (!uniqueClients.length) {
      return sendResponse(
        res, 
        404, 
        { count: 0 }, 
        "Aucun client avec un rendez-vous accepté trouvé."
      );
    }

    sendResponse(
      res, 
      200, 
      { 
        count: uniqueClients.length,
        clients: uniqueClients 
      },
      `${uniqueClients.length} client(s) trouvé(s) avec des rendez-vous acceptés.`
    );
  } catch (error) {
    console.error("[getClientsWithAcceptedAppointmentsForVeterinaire] Error:", error);
    next(error);
  }
};
