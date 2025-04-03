import { Request, Response, NextFunction } from "express";
import Appointment, { AppointmentStatus } from "../models/Appointment";
import User from "../models/User";
import Animal from "../models/Animal";

// Créer un rendez-vous pour un vétérinaire spécifique
export const createAppointment = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { date, animalName, type } = req.body;
      const user = (req as any).user; // L'utilisateur authentifié à partir du token
  
      // Vérification du rôle de l'utilisateur
      if (!user || user.role !== "client") {
        res.status(403).json({ message: "Accès interdit" });
        return;
      }
  
      // Vérifier si le client existe
      const client = await User.findById(user.id);
      if (!client) {
        res.status(404).json({ error: "Client non trouvé" });
        return;
      }
  
      // Vérifier si l'utilisateur possède un animal avec ce nom
      const animal = await Animal.findOne({ owner: user.id, name: animalName });
      if (!animal) {
        res.status(400).json({ error: `Aucun animal nommé "${animalName}" trouvé pour cet utilisateur` });
        return;
      }
  
      // Trouver un vétérinaire disponible
      const veterinaire = await User.findOne({ role: "veterinaire" });
      if (!veterinaire) {
        res.status(404).json({ error: "Vétérinaire non trouvé" });
        return;
      }
  
      // Créer un rendez-vous
      const appointment = new Appointment({
        clientId: user.id,
        clientFirstName: client.firstName,
        clientLastName: client.lastName,
        veterinaire: veterinaire._id,
        veterinaireFirstName: veterinaire.firstName,
        veterinaireLastName: veterinaire.lastName,
        date,
        animalName,
        type,
        status: AppointmentStatus.PENDING,
      });
  
      // Sauvegarder le rendez-vous
      await appointment.save();
  
      res.status(201).json({ message: "Rendez-vous créé avec succès", appointment });
    } catch (error) {
      next(error);
    }
  };
  
  
// Récupérer tous les rendez-vous
export const getAppointments = async (req: Request, res: Response): Promise<void> => {
  try {
    const appointments = await Appointment.find();
    res.status(200).json(appointments);
  } catch (error) {
    res.status(500).json({ error: "Erreur lors de la récupération des rendez-vous" });
  }
};

// Récupérer un rendez-vous par ID
export const getAppointmentById = async (req: Request, res: Response): Promise<void> => {
  try {
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) {
      res.status(404).json({ error: "Rendez-vous non trouvé" });
      return;
    }
    res.status(200).json(appointment);
  } catch (error) {
    res.status(500).json({ error: "Erreur lors de la récupération du rendez-vous" });
  }
};

// Accepter un rendez-vous
export const acceptAppointment = async (req: Request, res: Response): Promise<void> => {
  try {
    const appointment = await Appointment.findByIdAndUpdate(
      req.params.id,
      { status: "accepted" },
      { new: true }
    );
    if (!appointment) {
      res.status(404).json({ error: "Rendez-vous non trouvé" });
      return;
    }
    res.status(200).json(appointment);
  } catch (error) {
    res.status(500).json({ error: "Erreur lors de l'acceptation du rendez-vous" });
  }
};

// Refuser un rendez-vous
export const rejectAppointment = async (req: Request, res: Response): Promise<void> => {
  try {
    const appointment = await Appointment.findByIdAndUpdate(
      req.params.id,
      { status: "rejected" },
      { new: true }
    );
    if (!appointment) {
      res.status(404).json({ error: "Rendez-vous non trouvé" });
      return;
    }
    res.status(200).json(appointment);
  } catch (error) {
    res.status(500).json({ error: "Erreur lors du refus du rendez-vous" });
  }
};

// Récupérer les rendez-vous d'un client spécifique
export const getAppointmentsByClient = async (req: Request, res: Response): Promise<void> => {
  try {
    const { clientId } = req.params;
    const appointments = await Appointment.find({ clientId });

    if (!appointments.length) {
      res.status(404).json({ message: "Aucun rendez-vous trouvé pour ce client." });
      return;
    }
    res.status(200).json(appointments);
  } catch (error) {
    res.status(500).json({ error: "Erreur serveur", details: error });
  }
};

// Récupérer les rendez-vous d'un vétérinaire spécifique
export const getAppointmentsByVeterinaire = async (req: Request, res: Response): Promise<void> => {
  try {
    const { veterinaireId } = req.params;
    const appointments = await Appointment.find({ veterinaireId });

    if (!appointments.length) {
      res.status(404).json({ message: "Aucun rendez-vous trouvé pour ce vétérinaire." });
      return;
    }
    res.status(200).json(appointments);
  } catch (error) {
    res.status(500).json({ error: "Erreur serveur", details: error });
  }
};

// Supprimer un rendez-vous
export const deleteAppointment = async (req: Request, res: Response): Promise<void> => {
  try {
    const appointment = await Appointment.findByIdAndDelete(req.params.id);
    if (!appointment) {
      res.status(404).json({ error: "Rendez-vous non trouvé" });
      return;
    }
    res.status(200).json({ message: "Rendez-vous supprimé avec succès" });
  } catch (error) {
    res.status(500).json({ error: "Erreur lors de la suppression du rendez-vous" });
  }
};

// Mettre à jour un rendez-vous
export const updateAppointment = async (req: Request, res: Response): Promise<void> => {
  try {
    const appointmentId = req.params.id;
    const updatedData = req.body;

    // Mettre à jour le rendez-vous en utilisant l'ID
    const updatedAppointment = await Appointment.findByIdAndUpdate(appointmentId, updatedData, { new: true });

    if (!updatedAppointment) {
      res.status(404).json({ error: "Rendez-vous non trouvé" });
      return;
    }

    res.status(200).json(updatedAppointment);
  } catch (error) {
    res.status(500).json({ error: "Erreur lors de la mise à jour du rendez-vous" });
  }
};
