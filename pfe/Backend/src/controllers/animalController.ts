import { Request, Response } from "express";
import * as animalService from "../services/animalService";
import { upload } from "../services/animalMulterConfig";
import { IAnimal } from "../models/Animal";
import fs from "fs"
import path from "path";

export const createAnimal = async (req: Request, res: Response): Promise<void> => {
  upload(req, res, async (err) => {
    // Vérification d'erreur lors de l'upload de l'image
    if (err) {
      return res.status(400).json({
        message: "Erreur lors de l'upload de l'image",
        error: err.message,
      });
    }

    try {
      const { userId } = req.params;
      const { name, species, breed, gender, birthDate } = req.body;



      // Vérification de la validité de birthDate si elle est fournie
      if (birthDate && isNaN(new Date(birthDate).getTime())) {
        return res.status(400).json({ message: "La date de naissance est invalide." });
      }

      // Vérifier si l'animal existe déjà pour cet utilisateur
      const existingAnimal = await animalService.getAnimalByName(userId, name);
      if (existingAnimal) {
        return res.status(400).json({
          message: `Un animal nommé "${name}" existe déjà pour cet utilisateur.`,
        });
      }

      // Construction de l'URL de l'image si présente
      const imageUrl = req.file
        ? `${req.protocol}://${req.get('host')}/uploads/animals/${req.file.filename}`
        : null; 

      // Création de l'animal
      const newAnimal = await animalService.createAnimal(userId, {
        name,
        species,
        breed,
        gender: gender ?? undefined, // Si pas de genre, laisser undefined
        birthDate: birthDate ? new Date(birthDate) : undefined, // Date valide si présente
        picture: imageUrl, // L'URL de l'image (ou null si non présente)
      });

      // Réponse après la création de l'animal
      return res.status(201).json(newAnimal);
    } catch (error: any) {
      return res.status(500).json({
        message: "Erreur lors de l'ajout de l'animal",
        error: error.message || error,
      });
    }
  });
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
  upload(req, res, async (err) => {
    // Vérification d'erreur lors de l'upload de l'image
    if (err) {
      return res.status(400).json({
        message: "Erreur lors de l'upload de l'image",
        error: err.message,
      });
    }

    try {
      const { userId, animalId } = req.params;
      const { name, species, breed, gender, birthDate } = req.body;

      // Vérifier si l'animal existe déjà pour cet utilisateur
      const existingAnimal = await animalService.getAnimalByName(userId, name);
      if (existingAnimal) {
        return res.status(400).json({
          message: `Un animal nommé "${name}" existe déjà pour cet utilisateur.`,
        });
      }


      // Vérification de la validité de birthDate si elle est fournie
      if (birthDate && isNaN(new Date(birthDate).getTime())) {
        return res.status(400).json({ message: "La date de naissance est invalide." });
      }

      // Construire les données mises à jour
      const updatedData: Partial<IAnimal> = {
        name,
        species,
        breed,
        gender: gender ?? undefined, // Si pas de genre, laisser undefined
        birthDate: birthDate ? new Date(birthDate) : undefined, // Date valide si présente
      };

      // Si une image est uploadée, construire l'URL de l'image
      if (req.file) {
        const filename = req.file.filename;
        updatedData.picture = `${req.protocol}://${req.get('host')}/uploads/animals/${filename}`;
      }

      // Mettre à jour l'animal dans la base de données
      const updatedAnimal = await animalService.updateAnimal(userId, animalId, updatedData);

      if (!updatedAnimal) {
        return res.status(404).json({ message: "Animal non trouvé ou non autorisé" });
      }

      // Réponse après la mise à jour de l'animal
      return res.status(200).json(updatedAnimal);
    } catch (error: any) {
      return res.status(500).json({
        message: "Erreur lors de la mise à jour de l'animal",
        error: error.message || error,
      });
    }
  });
};



// 📌 Supprimer un animal d'un utilisateur
export const deleteAnimal = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId, animalId } = req.params;
    
    // 1. Get the animal to check if it exists and get the image path
    const animal = await animalService.getAnimalById(userId, animalId);
    
    if (!animal) {
      res.status(404).json({ 
        success: false,
        message: "Animal non trouvé ou non autorisé" 
      });
      return;
    }

    // 2. Delete the animal from database
    const deletedAnimal = await animalService.deleteAnimal(userId, animalId);
    
    if (!deletedAnimal) {
      res.status(500).json({
        success: false,
        message: "Une erreur inattendue est survenue lors de la suppression"
      });
      return;
    }

    // 3. If animal had an image, delete the file from server
    if (animal.picture) {
      const filename = animal.picture.split('/').pop();
      if (filename) {
        const filePath = path.join(__dirname, '..', 'uploads', 'animals', filename);
        
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      }
    }

    // 4. Send response (no return value needed)
    res.status(200).json({ 
      success: true,
      message: "Animal supprimé avec succès",
      data: { deletedAnimalId: animalId }
    });

  } catch (error: unknown) {
    console.error("Error deleting animal:", error);
    const errorMessage = error instanceof Error ? error.message : 'Erreur inconnue';
    res.status(500).json({ 
      success: false,
      message: "Erreur lors de la suppression de l'animal",
      error: process.env.NODE_ENV === 'development' ? errorMessage : undefined
    });
  }
};