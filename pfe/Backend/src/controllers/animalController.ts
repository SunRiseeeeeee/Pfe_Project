import { Request, Response } from "express";
import * as animalService from "../services/animalService";

// 📌 Ajouter un animal
export const createAnimal = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const newAnimal = await animalService.createAnimal(userId, req.body);
    res.status(201).json(newAnimal); // Send response here
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de l'ajout de l'animal", error });
  }
};

// 📌 Récupérer tous les animaux d'un utilisateur
export const getAnimalsByUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const animals = await animalService.getAnimalsByUser(userId);
    res.status(200).json(animals); // Send response here
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de la récupération des animaux", error });
  }
};

// 📌 Récupérer un animal spécifique d'un utilisateur
export const getAnimalById = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId, animalId } = req.params;
    const animal = await animalService.getAnimalById(userId, animalId);
    if (!animal) {
      res.status(404).json({ message: "Animal non trouvé" }); // Send response here
      return; // Exit the function
    }
    res.status(200).json(animal); // Send response here
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de la récupération de l'animal", error });
  }
};

// 📌 Mettre à jour un animal d'un utilisateur
export const updateAnimal = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId, animalId } = req.params;
    const updatedAnimal = await animalService.updateAnimal(userId, animalId, req.body);
    if (!updatedAnimal) {
      res.status(404).json({ message: "Animal non trouvé ou non autorisé" }); // Send response here
      return; // Exit the function
    }
    res.status(200).json(updatedAnimal); // Send response here
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de la mise à jour de l'animal", error });
  }
};

// 📌 Supprimer un animal d'un utilisateur
export const deleteAnimal = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId, animalId } = req.params;
    const deletedAnimal = await animalService.deleteAnimal(userId, animalId);
    if (!deletedAnimal) {
      res.status(404).json({ message: "Animal non trouvé ou non autorisé" }); // Send response here
      return; // Exit the function
    }
    res.status(200).json({ message: "Animal supprimé avec succès" }); // Send response here
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de la suppression de l'animal", error });
  }
};