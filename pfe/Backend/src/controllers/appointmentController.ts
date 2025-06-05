import { Request, Response, NextFunction, RequestHandler } from "express";
import mongoose from "mongoose";
import Appointment, { AppointmentStatus, AppointmentType, IAppointment } from "../models/Appointment";
import User, { UserRole } from "../models/User";
import { UserTokenPayload } from "../middlewares/authMiddleware";
import Animal from "../models/Animal";
import { DateTime } from "luxon";

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
        `Type de rendez-vous invalide. Autorisés : ${Object.values(AppointmentType).join(", ")}.`
      );
    }

    // Vérification du client
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

    // ✅ Conversion de la date en tenant compte du fuseau horaire local (Tunisie)
    const appointmentDate = DateTime.fromISO(date, { zone: "Africa/Tunis" }).toJSDate();
    if (!appointmentDate || isNaN(appointmentDate.getTime())) {
      return sendResponse(res, 400, {}, "Format de date invalide.");
    }

    // Vérification des conflits de créneau (±29 min)
    const windowStart = new Date(appointmentDate.getTime() - 29 * 60 * 1000);
    const windowEnd = new Date(appointmentDate.getTime() + 29 * 60 * 1000);

    const conflicting = await Appointment.find({
      veterinaireId: veterinaire._id,
      date: { $gte: windowStart, $lte: windowEnd },
      status: AppointmentStatus.ACCEPTED,
    });

    if (conflicting.length > 0) {
      return sendResponse(
        res,
        400,
        {},
        "Créneau indisponible : un autre rendez-vous accepté est déjà prévu dans cette plage horaire (±30 min)."
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
    const { page = 1 } = req.query;

    if (!mongoose.Types.ObjectId.isValid(clientId)) {
      res.status(400).json({ message: "ID de client invalide." });
      return;
    }

    const pageNumber = Math.max(Number(page), 1);
    const limit = 10;
    const skip = (pageNumber - 1) * limit;

    try {
      // Vérification de l'existence du client
      const exists = await User.exists({ _id: clientId, role: UserRole.CLIENT });
      if (!exists) {
        res.status(404).json({ message: "Client non trouvé." });
        return;
      }

      // Récupération de tous les rendez-vous du client
      const allAppointments = await Appointment.find({ clientId })
        .populate("veterinaireId", "-password -refreshToken")
        .populate("animalId")
        .lean<IAppointment[]>();

      // Filtrage et tri
      const pendingAppointments = allAppointments
        .filter(a => a.status === AppointmentStatus.PENDING)
        .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

      const acceptedAppointments = allAppointments
        .filter(a => a.status === AppointmentStatus.ACCEPTED)
        .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

      // Fusionner les deux listes triées
      const sortedAppointments = [...pendingAppointments, ...acceptedAppointments];

      if (!sortedAppointments.length) {
        res.status(404).json({ message: "Aucun rendez-vous pending/accepted trouvé pour ce client." });
        return;
      }

      // Pagination
      const paginatedAppointments = sortedAppointments.slice(skip, skip + limit);

      res.status(200).json({
        appointments: paginatedAppointments,
        currentPage: pageNumber,
        totalPages: Math.ceil(sortedAppointments.length / limit),
        totalAppointments: sortedAppointments.length,
      });
    } catch (err) {
      console.error("[getAppointmentsByClient] Error:", err);
      next(err);
    }
  };
// Historique vétérinaire
export const getAppointmentsByVeterinaire: RequestHandler<{ veterinaireId: string }> =
  async (req, res, next) => {
    const { veterinaireId } = req.params;
    const { page = 1 } = req.query; // On récupère le numéro de page depuis la requête, par défaut 1

    if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
      res.status(400).json({ message: "ID vétérinaire invalide." });
      return;
    }

    const pageNumber = Math.max(Number(page), 1); // On s'assure que la page est au minimum 1
    const limit = 10;
    const skip = (pageNumber - 1) * limit;

    try {
      // Vérification de l'existence du vétérinaire
      const exists = await User.exists({ _id: veterinaireId, role: UserRole.VETERINAIRE });
      if (!exists) {
        res.status(404).json({ message: "Vétérinaire non trouvé." });
        return;
      }

      // Récupération de tous les rendez-vous du vétérinaire
      const allAppointments = await Appointment.find({ veterinaireId })
        .populate("clientId", "-password -refreshToken")
        .populate("animalId")
        .lean<IAppointment[]>();

      // Filtrage et tri
      const pendingAppointments = allAppointments
        .filter(a => a.status === AppointmentStatus.PENDING)
        .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

      const acceptedAppointments = allAppointments
        .filter(a => a.status === AppointmentStatus.ACCEPTED)
        .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

      // Fusionner les deux listes triées
      const sortedAppointments = [...pendingAppointments, ...acceptedAppointments];

      if (!sortedAppointments.length) {
        res.status(404).json({ message: "Aucun rendez-vous trouvé pour ce vétérinaire." });
        return;
      }

      // Pagination
      const paginatedAppointments = sortedAppointments.slice(skip, skip + limit);

      res.status(200).json({
        appointments: paginatedAppointments,
        currentPage: pageNumber,
        totalPages: Math.ceil(sortedAppointments.length / limit),
        totalAppointments: sortedAppointments.length,
      });
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
    const { firstName, lastName } = req.query as { firstName?: string; lastName?: string };

    if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
      return sendResponse(res, 400, {}, "ID de vétérinaire invalide.");
    }

    // Vérifier si le vétérinaire existe
    const veterinaireExists = await User.exists({ _id: veterinaireId, role: UserRole.VETERINAIRE });
    if (!veterinaireExists) {
      return sendResponse(res, 404, {}, "Vétérinaire non trouvé.");
    }

    // Construire les filtres pour firstName et lastName
    const clientFilters: any = {};
    if (firstName) {
      clientFilters.firstName = { $regex: firstName, $options: "i" };
    }
    if (lastName) {
      clientFilters.lastName = { $regex: lastName, $options: "i" };
    }

    // Récupérer les rendez-vous acceptés avec les informations des clients
    const appointments = await Appointment.find({
      veterinaireId,
      status: AppointmentStatus.ACCEPTED,
    }).populate({
      path: "clientId",
      select: "firstName lastName email phoneNumber address profilePicture",
      match: clientFilters, // Appliquer les filtres sur firstName et lastName
    });

    // Filtrer les rendez-vous où clientId n'est pas null (car le match peut retourner null si aucun client ne correspond)
    const validAppointments = appointments.filter((a) => a.clientId !== null);

    // Extraire les clients sans doublons
    const uniqueClients = Array.from(
      new Map(
        validAppointments.map((a) => [a.clientId._id.toString(), a.clientId])
      ).values()
    );

    if (!uniqueClients.length) {
      return sendResponse(
        res,
        404,
        { count: 0 },
        "Aucun client avec un rendez-vous accepté trouvé" +
          (firstName || lastName ? " pour les critères de recherche spécifiés." : ".")
      );
    }

    sendResponse(
      res,
      200,
      {
        count: uniqueClients.length,
        clients: uniqueClients,
      },
      `${uniqueClients.length} client(s) trouvé(s) avec des rendez-vous acceptés` +
        (firstName || lastName ? " pour les critères de recherche spécifiés." : ".")
    );
  } catch (error) {
    console.error("[getClientsWithAcceptedAppointmentsForVeterinaire] Error:", error);
    next(error);
  }
};
// Fonction pour récupérer les animaux d'un client avec au moins un rendez-vous accepté chez un vétérinaire spécifique

export const getClientAnimalsWithAcceptedAppointments = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { clientId, veterinaireId } = req.params;

    // ✅ Validation des IDs
    if (!mongoose.Types.ObjectId.isValid(clientId)) {
      return sendResponse(res, 400, {}, "ID de client invalide.");
    }
    if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
      return sendResponse(res, 400, {}, "ID de vétérinaire invalide.");
    }

    // ✅ Vérification de l'existence du client et du vétérinaire
    const [clientExists, veterinaireExists] = await Promise.all([
      User.exists({ _id: clientId, role: UserRole.CLIENT }),
      User.exists({ _id: veterinaireId, role: UserRole.VETERINAIRE }),
    ]);

    if (!clientExists) {
      return sendResponse(res, 404, {}, "Client non trouvé.");
    }
    if (!veterinaireExists) {
      return sendResponse(res, 404, {}, "Vétérinaire non trouvé.");
    }

    // ✅ Récupérer les rendez-vous acceptés pour ce client et ce vétérinaire
    const acceptedAppointments = await Appointment.find({
      clientId,
      veterinaireId,
      status: AppointmentStatus.ACCEPTED
    }).select('animalId animalType');

    console.log("✅ Liste des rendez-vous récupérés :", acceptedAppointments);

    // 🚩 Vérification des IDs récupérés
    if (acceptedAppointments.length === 0) {
      return sendResponse(
        res,
        404,
        { count: 0 },
        "Aucun animal trouvé avec des rendez-vous acceptés chez ce vétérinaire."
      );
    }

    // ✅ Récupérer les détails complets des animaux concernés
    const animalIds = acceptedAppointments.map((appointment) => appointment.animalId);

    // Assurez-vous que `animalIds` contient des ObjectId valides
    const animals = await Animal.find({
      _id: { $in: animalIds },
      owner: new mongoose.Types.ObjectId(clientId), // Vérification que l'animal appartient au client
    }).select("-__v");

    // 🚩 Vérification du résultat final
    if (animals.length === 0) {
      return sendResponse(
        res,
        404,
        { count: 0 },
        "Les animaux avec des rendez-vous acceptés existent, mais ils ne correspondent pas au client spécifié."
      );
    }

    sendResponse(
      res,
      200,
      {
        count: animals.length,
        animals,
      },
      `${animals.length} animal(s) trouvé(s) avec des rendez-vous acceptés chez ce vétérinaire.`
    );
  } catch (error) {
    console.error("[getClientAnimalsWithAcceptedAppointments] Error:", error);
    next(error);
  }
};
