import { Request, Response } from "express";
import AnimalFiche from "../models/AnimalFiche";

const AnimalFicheController = {
    async createFiche(req: Request, res: Response) {
        try {
          const data = req.body;
          const fiche = new AnimalFiche(data);
          await fiche.save();
          res.status(201).json(fiche);
        } catch (error) {
          res.status(500).json({ message: (error as Error).message });
        }
      },
    
  // Récupérer une fiche par ID
  async getFicheById(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const fiche = await AnimalFiche.findById(id).populate("animal veterinarian");
      if (!fiche) {
        return res.status(404).json({ message: "Fiche not found" });
      }
      res.status(200).json(fiche);
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  },

  // Créer une nouvelle fiche

  // Supprimer une fiche par ID
  async deleteFiche(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const fiche = await AnimalFiche.findByIdAndDelete(id);
      if (!fiche) {
        return res.status(404).json({ message: "Fiche not found" });
      }
      res.status(200).json({ message: "Fiche deleted successfully" });
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  },

  // Ajouter un rendez-vous dans une fiche
  async addAppointment(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const { appointmentDate, diagnosis } = req.body;
      const appointment = { appointmentDate, diagnosis };

      const fiche = await AnimalFiche.findById(id);
      if (!fiche) {
        return res.status(404).json({ message: "Fiche not found" });
      }

      // Vérifier si 'appointments' est défini, sinon l'initialiser
      if (!fiche.appointments) {
        fiche.appointments = [];
      }

      fiche.appointments.push(appointment);
      await fiche.save();

      res.status(200).json(fiche);
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  },

  // Mettre à jour une fiche
  async updateFiche(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const data = req.body;
      const updatedFiche = await AnimalFiche.findByIdAndUpdate(id, data, { new: true }).populate("animal veterinarian");
      if (!updatedFiche) {
        return res.status(404).json({ message: "Fiche not found" });
      }
      res.status(200).json(updatedFiche);
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  }
};

export default AnimalFicheController;
