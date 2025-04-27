import { Request, Response, NextFunction } from "express";
import Appointment, { AppointmentStatus } from "../models/Appointment";
import User from "../models/User";
import mongoose from "mongoose";

// Créer un rendez-vous
export const createAppointment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { date, animalType, type } = req.body;
    const user = req.user;

    if (!user || user.role !== "client") {
      res.status(403).json({ message: "Accès interdit" });
      return;
    }

    const client = await User.findById(user.id);
    if (!client) {
      res.status(404).json({ error: "Client non trouvé" });
      return;
    }

    const veterinaire = await User.findOne({ role: "veterinaire" });
    if (!veterinaire) {
      res.status(404).json({ error: "Vétérinaire non trouvé" });
      return;
    }

    const appointment = new Appointment({
      clientId: user.id,
      veterinaireId: veterinaire._id,
      date,
      animalType,
      type,
      status: AppointmentStatus.PENDING,
    });

    await appointment.save();

    res.status(201).json({ message: "Rendez-vous créé avec succès", appointment });
  } catch (error) {
    next(error);
  }
};

// Récupérer un rendez-vous par ID
export const getAppointmentById = async (
  req: Request,
  res: Response
): Promise<void> => {
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
export const acceptAppointment = async (
  req: Request,
  res: Response
): Promise<void> => {
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
export const rejectAppointment = async (
  req: Request,
  res: Response
): Promise<void> => {
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

// Récupérer les rendez-vous d'un client
export const getAppointmentsByClient = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const { clientId } = req.params;
  try {
    if (!req.user) {
      res.status(401).json({ message: "Non authentifié" });
      return;
    }

    if (String(req.user.id) !== String(clientId)) {
      res.status(403).json({
        message: "Non autorisé à accéder à ces rendez-vous"
      });
      return;
    }

    const appointments = await Appointment.find({ clientId });

    if (!appointments.length) {
      res.status(404).json({
        message: "Aucun rendez-vous trouvé pour ce client"
      });
      return;
    }

    res.status(200).json(appointments);
  } catch (error) {
    console.error("Error in getAppointmentsByClient:", error);
    next(error);
  }
};

// Récupérer les rendez-vous d’un vétérinaire
export const getAppointmentsByVeterinaire = async (
  req: Request,
  res: Response
): Promise<void> => {
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
export const deleteAppointment = async (
  req: Request,
  res: Response
): Promise<void> => {
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
export const updateAppointment = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const appointmentId = req.params.id;
    const updatedData = req.body;

    const updatedAppointment = await Appointment.findByIdAndUpdate(
      appointmentId,
      updatedData,
      { new: true }
    );

    if (!updatedAppointment) {
      res.status(404).json({ error: "Rendez-vous non trouvé" });
      return;
    }

    res.status(200).json(updatedAppointment);
  } catch (error) {
    res.status(500).json({ error: "Erreur lors de la mise à jour du rendez-vous" });
  }
};

// Extension du type Request pour inclure l’utilisateur
declare module "express" {
  interface Request {
    user?: {
      id: string;
      role: string;
    };
  }
}
