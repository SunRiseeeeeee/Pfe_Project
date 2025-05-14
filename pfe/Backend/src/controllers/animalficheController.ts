import { Request, Response } from "express";
import AnimalFiche from "../models/AnimalFiche";

const AnimalFicheController = {
  // ✅ Créer une nouvelle fiche
  async createFiche(req: Request, res: Response) {
    try {
      const {
        client,
        animal,
        veterinarian,
        weight,
        height,
        temperature,
        diet,
        behaviorNotes,
        vaccinations,
        treatments,
        examinations,
        allergies,
        medicalHistory,
        recommendedNextVisit,
        generalNotes,
        appointments,
      } = req.body;

      // Vérification de la présence des données essentielles
      if (!client || !animal || !veterinarian) {
        return res.status(400).json({ message: "Client, Animal et Veterinarian sont requis." });
      }

      // Création d'une nouvelle fiche
      const fiche = new AnimalFiche({
        client,
        animal,
        veterinarian,
        weight,
        height,
        temperature,
        diet,
        behaviorNotes,
        vaccinations: vaccinations || [],
        treatments: treatments || [],
        examinations: examinations || [],
        allergies: allergies || [],
        medicalHistory,
        recommendedNextVisit,
        generalNotes,
        appointments: appointments || [],
        lastUpdate: new Date(),
      });

      // Sauvegarder la fiche dans la base de données
      await fiche.save();

      // Répondre avec la fiche créée
      res.status(201).json(fiche);
    } catch (error) {
      // Gérer les erreurs de manière précise
      res.status(500).json({ message: `Erreur lors de la création de la fiche : ${(error as Error).message}` });
    }
  },

  // ✅ Récupérer une fiche par ID (nom modifié pour éviter le conflit)
  async getFicheById(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const fiche = await AnimalFiche.findById(id).populate("animal veterinarian");

      if (!fiche) {
        return res.status(404).json({ message: "Fiche not found" });
      }

      res.status(200).json(fiche);
    } catch (error) {
      res.status(500).json({ message: `Erreur lors de la récupération de la fiche : ${(error as Error).message}` });
    }
  },
    // ✅ Récupérer une fiche par ID d'animal
    async getFicheByAnimalId(req: Request, res: Response) {
      try {
        const { animalId } = req.params;
        const fiche = await AnimalFiche.findOne({ animal: animalId }).populate("animal veterinarian client");
  
        if (!fiche) {
          return res.status(404).json({ message: "Aucune fiche trouvée pour cet animal" });
        }
  
        res.status(200).json(fiche);
      } catch (error) {
        res.status(500).json({ message: `Erreur lors de la récupération de la fiche : ${(error as Error).message}` });
      }
    },

  // ✅ Supprimer une fiche par ID
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

  // ✅ Ajouter un rendez-vous dans une fiche
// ✅ Ajouter un rendez-vous dans une fiche
async addAppointment(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const { appointmentDate, diagnosis } = req.body;
      const appointment = { appointmentDate, diagnosis };
  
      // Récupérer la fiche de l'animal
      const fiche = await AnimalFiche.findById(id);
      if (!fiche) {
        return res.status(404).json({ message: "Fiche not found" });
      }
  
      // ✅ Sécuriser l'initialisation de l'array si undefined
      if (!fiche.appointments) {
        fiche.appointments = [];
      }
  
      // Ajouter le rendez-vous
      fiche.appointments.push(appointment);
  
      // Mettre à jour la date de dernière modification
      fiche.lastUpdate = new Date();
  
      // Sauvegarder la fiche mise à jour
      await fiche.save();
  
      res.status(200).json(fiche);
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  },
  
  // ✅ Mettre à jour une fiche
async updateFiche(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const data = req.body;

      // Mettre à jour la date de dernière modification
      data.lastUpdate = new Date();

      const updatedFiche = await AnimalFiche.findByIdAndUpdate(id, data, {
        new: true,
      }).populate("animal veterinarian");

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
