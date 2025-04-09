import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";
import mongoose from "mongoose";

// 🔍 Récupérer un utilisateur par son ID
export const getUserById = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;

  if (!mongoose.Types.ObjectId.isValid(userId)) {
    res.status(400).json({ message: "ID utilisateur invalide" });
    return;
  }

  try {
    const user = await UserService.getUserById(userId);

    if (!user) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }

    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de la récupération de l'utilisateur" });
  }
};

// 🟢 Modifier les coordonnées d'un utilisateur
export const updateUser = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;
  const updateFields = req.body;

  if (!mongoose.Types.ObjectId.isValid(userId)) {
    res.status(400).json({ message: "ID utilisateur invalide" });
    return;
  }

  try {
    const updatedUser = await UserService.updateUser(userId, updateFields);

    if (!updatedUser) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }

    res.status(200).json({ message: "Coordonnées mises à jour avec succès", user: updatedUser });
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur lors de la mise à jour" });
  }
};

// 🔴 Supprimer un compte utilisateur
export const deleteUser = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;

  if (!mongoose.Types.ObjectId.isValid(userId)) {
    res.status(400).json({ message: "ID utilisateur invalide" });
    return;
  }

  try {
    const deletedUser = await UserService.deleteUser(userId);

    if (!deletedUser) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }

    res.status(200).json({ message: "Compte supprimé avec succès" });
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de la suppression du compte" });
  }
};

// 🟢 Récupérer tous les vétérinaires
export const getVeterinarians = async (_req: Request, res: Response): Promise<void> => {
  try {
    const veterinarians = await UserService.getVeterinarians();

    if (!veterinarians.length) {
      res.status(404).json({ message: "Aucun vétérinaire trouvé" });
      return;
    }

    res.status(200).json(veterinarians);
  } catch (error) {
    res.status(500).json({ message: "Erreur lors de la récupération des vétérinaires" });
  }
};
