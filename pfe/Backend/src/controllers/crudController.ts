import { Request, Response, NextFunction } from "express";
import { UserService } from "../services/userService";
import User, { UserRole } from "../models/User";
import mongoose from "mongoose";

interface IVeterinarianQuery {
  rating?: string;
  location?: string;
  page?: string;
  limit?: string;
  sort?: string;
}

// Type pour les contrôleurs Express
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

export const getVeterinarians: ExpressController = async (req, res) => {
  try {
    // Extraction et typage explicite des query params
    const rating = typeof req.query.rating === 'string' ? req.query.rating : undefined;
    const location = typeof req.query.location === 'string' ? req.query.location : undefined;
    const page = typeof req.query.page === 'string' ? req.query.page : "1";
    const limit = typeof req.query.limit === 'string' ? req.query.limit : "2";
    const sort = typeof req.query.sort === 'string' ? req.query.sort : "desc";

    const filter: Record<string, any> = { role: UserRole.VETERINAIRE };

    // Filtrage par rating
    if (rating) {
      const ratingNumber = parseFloat(rating);
      if (!isNaN(ratingNumber)) {
        filter.rating = { $gte: ratingNumber };
      }
    }

    // Filtrage par location (regex insensible à la casse)
    if (location) {
      filter.location = { $regex: new RegExp(location, "i") };
    }

    // Pagination avec validation
    const pageNumber = Math.max(1, parseInt(page) || 1);
    const limitNumber = Math.min(100, Math.max(1, parseInt(limit) || 10));
    const skip = (pageNumber - 1) * limitNumber;

    // Tri (par défaut : rating décroissant)
    const sortOrder = sort === "asc" ? 1 : -1;

    const [veterinarians, totalCount] = await Promise.all([
      User.find(filter)
        .sort({ rating: sortOrder })
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