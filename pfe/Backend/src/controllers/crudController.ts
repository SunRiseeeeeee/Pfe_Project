import { Request, Response, NextFunction } from "express";
import { UserService } from "../services/userService";
import User, { UserRole } from "../models/User";
import mongoose from "mongoose";

// Type local pour les contrôleurs Express
type ExpressController = (req: Request, res: Response, next?: NextFunction) => Promise<void>;

export const getUserById: ExpressController = async (req, res) => {
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
    res.status(500).json({
      message: "Erreur lors de la récupération de l'utilisateur",
      error: error instanceof Error ? error.message : "Erreur inconnue"
    });
  }
};

export const updateUser: ExpressController = async (req, res) => {
  const { userId } = req.params;
  const updateFields = { ...req.body };

  if (!mongoose.Types.ObjectId.isValid(userId)) {
    res.status(400).json({ message: "ID utilisateur invalide" });
    return;
  }

  // ❌ Bloquer la modification de l'email ou du rôle uniquement si une valeur est fournie
  if (
    Object.prototype.hasOwnProperty.call(updateFields, 'email') ||
    Object.prototype.hasOwnProperty.call(updateFields, 'role')
  ) {
    res.status(403).json({
      message: "La modification de l'email ou du rôle n'est pas autorisée"
    });
    return;
  }

  try {
    const updatedUser = await UserService.updateUser(userId, updateFields);
    if (!updatedUser) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }
    res.status(200).json({
      message: "Coordonnées mises à jour avec succès",
      user: updatedUser
    });
  } catch (error) {
    res.status(400).json({
      message: error instanceof Error ? error.message : "Erreur lors de la mise à jour"
    });
  }
};




export const deleteUser: ExpressController = async (req, res) => {
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
    res.status(500).json({
      message: "Erreur lors de la suppression du compte",
      error: error instanceof Error ? error.message : "Erreur inconnue"
    });
  }
};

export const getVeterinarians = async (req: Request, res: Response): Promise<void> => {
  try {
    // Extraction et parsing sécurisé des query params
    const rating = parseFloat(req.query.rating as string);
    const location = req.query.location as string | undefined;
    const services = (req.query.services as string | undefined)?.split(",");
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 10;
    const sort = req.query.sort === "asc" ? "asc" : "desc";

    const filter: Record<string, any> = {
      role: UserRole?.VETERINAIRE || "VETERINAIRE"
    };

    // Filtrage par rating minimum
    if (!isNaN(rating)) {
      filter.rating = { $gte: rating };
    }

    // Filtrage par location (street, city, state, country)
    if (location) {
      const regex = new RegExp(location, "i");
      filter.$or = [
        { "address.street": regex },
        { "address.city": regex },
        { "address.state": regex },
        { "address.country": regex }
      ];
    }

    // Filtrage par services proposés
    if (services && services.length > 0) {
      filter["details.services"] = { $in: services };
    }

    // Pagination et tri
    const pageNumber = Math.max(1, page);
    const limitNumber = Math.min(100, Math.max(1, limit));
    const skip = (pageNumber - 1) * limitNumber;
    const sortOrder = sort === "asc" ? 1 : -1;

    // Requête principale et comptage total
    const [veterinarians, totalCount] = await Promise.all([
      User.find(filter, "-password -refreshToken")
        .sort({ rating: sortOrder, lastName: 1 }) // tri combiné
        .skip(skip)
        .limit(limitNumber),
      User.countDocuments(filter)
    ]);

    if (veterinarians.length === 0) {
      res.status(404).json({ message: "Aucun vétérinaire trouvé" });
      return;
    }

    res.status(200).json({
      currentPage: pageNumber,
      totalPages: Math.ceil(totalCount / limitNumber),
      totalCount,
      veterinarians
    });

  } catch (error) {
    console.error("Erreur lors de la récupération des vétérinaires:", error);
    res.status(500).json({
      message: "Erreur serveur",
      error: error instanceof Error ? error.message : "Erreur inconnue"
    });
  }
};