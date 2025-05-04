import { Request, Response, NextFunction, RequestHandler } from "express";
import mongoose from "mongoose";
import Appointment, { AppointmentStatus, AppointmentType } from "../models/Appointment";
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

export const createAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    
    const { date, animalType, type, services, veterinaireId } = req.body;
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
      return sendResponse(res, 400, {}, `Type de rendez-vous invalide. Autorisés : ${Object.values(AppointmentType).join(", ")}`);
    }

    // Vérification de l'existence du client
    const client = await User.findById(user.id);
    if (!client) {
      return sendResponse(res, 404, {}, "Client non trouvé.");
    }

    // Vérification que l'animal appartient bien à ce client
    const animal = await Animal.findOne({ _id: animalId, owner: client._id });
    if (!animal) {
      return sendResponse(res, 404, {}, "Animal non trouvé ou n'appartient pas à ce client.");
    }

    // Vérification du vétérinaire
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

    // Convertir la date en objet Date
    const appointmentDate = new Date(date);
    
    // Vérifier la disponibilité du créneau
    const existingAppointments = await Appointment.find({
      veterinaireId: veterinaire._id,
      date: {
        $gte: new Date(appointmentDate.getTime() - 20 * 60000), // 20 minutes avant
        $lte: new Date(appointmentDate.getTime() + 20 * 60000)  // 20 minutes après
      },
      status: { $ne: AppointmentStatus.REJECTED } // On ne compte pas les rendez-vous rejetés
    });

    if (existingAppointments.length > 0) {
      return sendResponse(
        res, 
        400, 
        {}, 
        "Créneau indisponible. Il doit y avoir au moins 20 minutes entre deux rendez-vous."
      );
    }

    // Création du rendez-vous
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

export const getAppointmentForVeterinaireById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params; // Récupère l'ID du rendez-vous depuis les paramètres

    // Vérifie si l'ID du rendez-vous est valide
    if (!mongoose.Types.ObjectId.isValid(id)) {
      res.status(400).json({ message: "ID de rendez-vous invalide" });
      return;
    }

    // Recherche du rendez-vous dans la base de données
    const appointment = await Appointment.findById(id)
      .populate("clientId", "-password -refreshToken") // Popule les données du client sans mot de passe ni refreshToken
      .populate("animalId"); // Popule les données de l'animal

    // Si aucun rendez-vous n'est trouvé
    if (!appointment) {
      res.status(404).json({ message: "Rendez-vous non trouvé" });
      return;
    }

    // Vérifie si le vétérinaire connecté est bien celui assigné au rendez-vous
    // Cette vérification peut être supprimée si le vétérinaire n'a pas besoin d'être authentifié
    // if (appointment.veterinaireId.toString() !== user.id) {
    //   res.status(403).json({ message: "Accès interdit : vous n’êtes pas le vétérinaire assigné." });
    //   return;
    // }

    // Si tout est ok, retourne les informations du rendez-vous
    res.status(200).json({ appointment });
  } catch (error) {
    // En cas d'erreur, log l'erreur et passe au middleware suivant
    console.error("[getAppointmentForVeterinaireById] Error:", error);
    next(error);
  }
};


export const getAppointmentForClientById = async (
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
      .populate("veterinaireId", "-password -refreshToken")
      .populate("animalId");

    if (!appointment) {
      res.status(404).json({ message: "Rendez-vous non trouvé." });
      return;
    }

    // Ne plus vérifier l'utilisateur authentifié
    // Vérifier si l'ID du client correspond à celui du rendez-vous
    if (appointment.clientId.toString() !== req.params.clientId) {
      res.status(403).json({ message: "Accès interdit : vous n’êtes pas le client concerné." });
      return;
    }

    res.status(200).json({ appointment });
  } catch (error) {
    console.error("[getAppointmentForClientById] Error:", error);
    next(error);
  }
};


export const getAppointmentsByClient: RequestHandler<{ clientId: string }> =
  async (req, res, next) => {
    try {
      const { clientId } = req.params;

      // 1) Validation de l'ID client
      if (!mongoose.Types.ObjectId.isValid(clientId)) {
        res.status(400).json({ message: "Format d'ID client invalide" });
        return;
      }

      // 2) Vérification que le client existe
      const client = await User.findOne({ _id: clientId, role: "client" }).select("_id");
      if (!client) {
        res.status(404).json({ message: "Client non trouvé" });
        return;
      }

      // 3) Récupération des rendez-vous
      const appointments = await Appointment.find({ clientId })
        .populate({
          path: "veterinaireId",
          select: "firstName lastName specialty -_id"
        })
        .populate({
          path: "animalId",
          select: "name breed -_id"
        })
        .select("-__v -createdAt -updatedAt")
        .sort({ date: -1 })
        .lean();

      // 4) Envoi de la réponse
      res.status(200).json(appointments);
    } catch (error: unknown) {
      console.error("[getAppointmentsByClient] Error:", error);
      next(error instanceof Error ? error : new Error("Erreur serveur"));
    }
  };
  export const getAppointmentsByVeterinaire: RequestHandler<{ veterinaire: string }> =
  async (req, res, next) => {
    try {
      const veterinaireId = req.params.veterinaire.trim();

      // 1) Validation de l'ID vétérinaire
      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        res.status(400).json({ message: "ID vétérinaire invalide" });
        return;
      }

      // 2) Vérification que le vétérinaire existe
      const veterinaire = await User.findById(veterinaireId);
      if (!veterinaire) {
        res.status(404).json({ message: "Vétérinaire non trouvé" });
        return;
      }

      // 3) Récupère tous les rendez-vous
      const allAppointments = await Appointment.find({ veterinaireId })
        .populate("clientId", "-password -refreshToken")
        .populate("animalId");

      console.log(`[DEBUG] Total appts for vet ${veterinaireId}:`, allAppointments.length);
      console.log(`[DEBUG] Statuts bruts:`, allAppointments.map(a => a.status));

      // 4) Nettoie et filtre en mémoire
      const filtered = allAppointments
        .map(a => {
          const statusClean = a.status.trim().replace(/,$/, "");
          return { ...a.toObject(), status: statusClean };
        })
        .filter(a => a.status === "pending" || a.status === "accepted");

      // 5) Trie par date ascendant
      filtered.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

      if (filtered.length === 0) {
        res.status(404).json({ message: "Aucun rendez-vous pending/accepted trouvé pour ce vétérinaire" });
        return;
      }

      console.log(`[DEBUG] Rendez-vous renvoyés (triés) :`, filtered);

      // 6) Envoi de la réponse
      res.status(200).json({ appointments: filtered });
    } catch (error: unknown) {
      console.error("[getAppointmentsByVeterinaire] Error:", error);
      next(error instanceof Error ? error : new Error("Erreur serveur"));
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
    const updatedData = { ...req.body };
    const user = req.user;

    // Vérifie si l'utilisateur est défini
    if (!user) {
      return sendResponse(res, 401, {}, "Utilisateur non authentifié");
    }

    // Vérification de la validité de l'ID de rendez-vous
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return sendResponse(res, 400, {}, "ID de rendez-vous invalide");
    }

    const appointment = await Appointment.findById(id);
    if (!appointment) {
      return sendResponse(res, 404, {}, "Rendez-vous non trouvé");
    }

    // Vérifie que seul le client propriétaire peut modifier le rendez-vous
    if (user.role !== UserRole.CLIENT || appointment.clientId.toString() !== user.id) {
      return sendResponse(res, 403, {}, "Accès interdit : vous ne pouvez pas modifier ce rendez-vous.");
    }

    // Vérifie que le statut est "pending" pour autoriser la modification
    if (appointment.status !== "pending") {
      return sendResponse(res, 403, {}, "Modification interdite : Le statut du rendez-vous n'est pas 'pending'.");
    }

    // Empêcher la modification de certains champs
    const protectedFields = ["clientId", "veterinaireId", "createdAt", "updatedAt", "_id", "__v"];
    for (const field of protectedFields) {
      delete updatedData[field];
    }

    // Si l'utilisateur tente de modifier l'animal, on vérifie sa propriété
    if (updatedData.animalId) {
      if (!mongoose.Types.ObjectId.isValid(updatedData.animalId)) {
        return sendResponse(res, 400, {}, "ID de l'animal invalide.");
      }

      const animal = await Animal.findOne({ _id: updatedData.animalId, owner: user.id });
      if (!animal) {
        return sendResponse(res, 403, {}, "Cet animal n'existe pas ou ne vous appartient pas.");
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

    // Retourner les informations mises à jour du rendez-vous
    sendResponse(res, 200, {
      id: updatedAppointment._id,
      date: updatedAppointment.date,
      animalId: updatedAppointment.animalId,
      type: updatedAppointment.type,
      status: updatedAppointment.status,
      services: updatedAppointment.services,
      caseDescription: updatedAppointment.caseDescription,
    }, "Rendez-vous mis à jour avec succès.");
  } catch (error) {
    console.error("[updateAppointment] Error:", error);
    next(error);
  }
};

