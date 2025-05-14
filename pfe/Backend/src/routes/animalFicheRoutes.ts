import express from "express";
import AnimalFicheController from "../controllers/animalficheController";

const router = express.Router();

// Récupérer une fiche animalière par ID
router.get("/:id", (req, res) => {
  AnimalFicheController.getFicheById(req, res);
});

// Créer une nouvelle fiche animalière
router.post("/", (req, res) => {
  AnimalFicheController.createFiche(req, res);
});
// Récupérer une fiche animalière par ID d'animal
router.get("/animal/:animalId/fiche", (req, res) => {
  AnimalFicheController.getFicheByAnimalId(req, res);
});

// Supprimer une fiche animalière par ID
router.delete("/:id", (req, res) => {
  AnimalFicheController.deleteFiche(req, res);
});

// Ajouter un rendez-vous dans une fiche animalière
router.post("/:id/appointments", (req, res) => {AnimalFicheController.addAppointment(req, res);});

// Mettre à jour une fiche animalière
router.put("/:id", (req, res) => {
  AnimalFicheController.updateFiche(req, res);
});

export default router;
