import { Request, Response, NextFunction } from "express";
import { UserService } from "../services/userService";
import User, { UserRole } from "../models/User";
import mongoose from "mongoose";

// Type pour les contrôleurs Express (retour void)
type ExpressController = (req: Request, res: Response, next?: NextFunction) => Promise<void>;

// Helper pour les réponses JSON
const sendJsonResponse = (
  res: Response,
  status: number,
  data: object
): void => {
  res.status(status).json(data);
};

export const getUserById: ExpressController = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      sendJsonResponse(res, 400, { message: "ID utilisateur invalide" });
      return;
    }

    const user = await UserService.getUserById(userId);
    if (!user) {
      sendJsonResponse(res, 404, { message: "Utilisateur non trouvé" });
      return;
    }

    sendJsonResponse(res, 200, user);
  } catch (error) {
    console.error("Erreur getUserById:", error);
    sendJsonResponse(res, 500, {
      message: "Erreur lors de la récupération de l'utilisateur",
      error: error instanceof Error ? error.message : "Erreur inconnue"
    });
  }
};

export const updateUser: ExpressController = async (req, res) => {
  try {
    const { userId } = req.params;
    const updateFields = { ...req.body };

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      sendJsonResponse(res, 400, { message: "ID utilisateur invalide" });
      return;
    }

    const protectedFields = ['email', 'role', 'password'];
    if (protectedFields.some(field => field in updateFields)) {
      sendJsonResponse(res, 403, {
        message: "La modification de certains champs n'est pas autorisée"
      });
      return;
    }

    const updatedUser = await UserService.updateUser(userId, updateFields);
    if (!updatedUser) {
      sendJsonResponse(res, 404, { message: "Utilisateur non trouvé" });
      return;
    }

    sendJsonResponse(res, 200, {
      message: "Coordonnées mises à jour avec succès",
      user: updatedUser
    });
  } catch (error) {
    console.error("Erreur updateUser:", error);
    sendJsonResponse(res, 400, {
      message: error instanceof Error ? error.message : "Erreur lors de la mise à jour"
    });
  }
};

export const deleteUser: ExpressController = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      sendJsonResponse(res, 400, { message: "ID utilisateur invalide" });
      return;
    }

    const result = await UserService.deleteUser(userId);
    if (!result) {
      sendJsonResponse(res, 404, { message: "Utilisateur non trouvé" });
      return;
    }

    sendJsonResponse(res, 200, { message: "Compte désactivé avec succès" });
  } catch (error) {
    console.error("Erreur deleteUser:", error);
    sendJsonResponse(res, 500, {
      message: "Erreur lors de la désactivation du compte",
      error: error instanceof Error ? error.message : "Erreur inconnue"
    });
  }
};

export const getVeterinarians: ExpressController = async (req, res) => {
  try {
    const { 
      rating: ratingParam, 
      location, 
      services: servicesParam,
      page: pageParam = '1',
      sort = 'desc'
    } = req.query;

    const rating = ratingParam ? parseFloat(ratingParam as string) : undefined;
    const services = servicesParam ? (servicesParam as string).split(',') : undefined;
    const page = Math.max(1, parseInt(pageParam as string) || 1);
    const limit = 10;
    const sortOrder = sort === 'asc' ? 1 : -1;

    const filter: any = { role: UserRole.VETERINAIRE };

    if (rating && !isNaN(rating)) {
      filter.rating = { $gte: rating };
    }

    if (location) {
      const regex = new RegExp(location as string, 'i');
      filter.$or = [
        { 'address.city': regex },
        { 'address.state': regex },
        { 'address.country': regex }
      ];
    }

    if (services?.length) {
      filter['details.services'] = { $in: services };
    }

    const [veterinarians, totalCount] = await Promise.all([
      User.find(filter, '-password -refreshToken')
        .sort({ rating: sortOrder, lastName: 1 })
        .skip((page - 1) * limit)
        .limit(limit),
      User.countDocuments(filter)
    ]);

    if (!veterinarians.length) {
      sendJsonResponse(res, 404, { message: "Aucun vétérinaire trouvé" });
      return;
    }

    sendJsonResponse(res, 200, {
      currentPage: page,
      totalPages: Math.ceil(totalCount / limit),
      totalCount,
      veterinarians
    });

  } catch (error) {
    console.error("Erreur getVeterinarians:", error);
    sendJsonResponse(res, 500, {
      message: "Erreur serveur",
      error: error instanceof Error ? error.message : "Erreur inconnue"
    });
  }
};

export const getVeterinaireById: ExpressController = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      sendJsonResponse(res, 400, { message: "ID invalide" });
      return;
    }

    const vet = await User.findOne({
      _id: userId,
      role: UserRole.VETERINAIRE
    }).select('-password -refreshToken');

    if (!vet) {
      sendJsonResponse(res, 404, { message: "Vétérinaire non trouvé" });
      return;
    }

    sendJsonResponse(res, 200, vet);
  } catch (error) {
    console.error("Erreur getVeterinaireById:", error);
    sendJsonResponse(res, 500, {
      message: error instanceof Error ? error.message : "Erreur serveur"
    });
  }
};