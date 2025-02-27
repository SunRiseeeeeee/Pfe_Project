import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";

// 🔍 Récupérer un utilisateur par son ID
export const getUserById = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params; // Récupère l'ID de l'utilisateur à partir des paramètres de l'URL

  try {
    // Appelle la méthode de UserService pour récupérer l'utilisateur par son ID
    const user = await UserService.getUserById(userId);

    // Si l'utilisateur n'est pas trouvé
    if (!user) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }

    // Si l'utilisateur est trouvé, on renvoie ses informations
    res.status(200).json(user);
  } catch (error) {
    // En cas d'erreur (par exemple, si l'ID n'est pas valide)
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur lors de la récupération de l'utilisateur" });
  }
};

// 🟢 Modifier les coordonnées d'un utilisateur
export const updateUser = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params; // ID de l'utilisateur à modifier
  const { firstName, lastName, username, email, phoneNumber, location, profilePicture } = req.body;

  try {
    const updatedUser = await UserService.updateUser(userId, { firstName, lastName, username, email, phoneNumber, location, profilePicture });

    if (!updatedUser) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }

    res.status(200).json({ message: "Coordonnées mises à jour avec succès", user: updatedUser });
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur lors de la mise à jour des coordonnées" });
  }
};

// 🔴 Supprimer un compte utilisateur
export const deleteUser = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;

  try {
    const deletedUser = await UserService.deleteUser(userId);

    if (!deletedUser) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }

    res.status(200).json({ message: "Compte supprimé avec succès" });
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur lors de la suppression du compte" });
  }
};

// 🔍 Récupérer tous les utilisateurs selon leur rôle
export const getUsersByRole = async (req: Request, res: Response): Promise<void> => {
  const { role } = req.params;

  // Vérification si le rôle est valide
  if (!Object.values(UserRole).includes(role as UserRole)) {
    res.status(400).json({ message: "Rôle invalide" });
    return;
  }

  try {
    const users = await UserService.getUsersByRole(role as UserRole);
    res.status(200).json(users);
  } catch (error) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur lors de la récupération des utilisateurs" });
  }
};
