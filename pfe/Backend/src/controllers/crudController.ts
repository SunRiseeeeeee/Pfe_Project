import { Request, Response, NextFunction, RequestHandler } from "express";
import { UserService } from "../services/userService";
import User, { UserRole } from "../models/User";
import mongoose from "mongoose";
import { userUpload } from '../services/userMulterConfig';
import ReviewRating from "../models/Review";
import Veterinaire from '../models/User'; // Ajuste le chemin selon ta structure
import Secretaire from '../models/User'; // Ajuste le chemin selon ta structure
import bcrypt from 'bcryptjs';

import path from "path";
import fs from 'fs';
import Review from "../models/Review";
import Rating from "../models/Rating";

declare global {
  namespace Express {
    interface Request {
      id?: string; // Déclaration de la propriété id optionnelle
      // Ajoutez d'autres propriétés personnalisées si nécessaire
    }
  }
}
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
  userUpload(req, res, async (uploadError) => {
    try {
      const { userId } = req.params;
      
      // Validation de l'ID utilisateur
      if (!mongoose.Types.ObjectId.isValid(userId)) {
        return sendJsonResponse(res, 400, { 
          success: false,
          message: "ID utilisateur invalide" 
        });
      }

      // Gestion des erreurs d'upload
      if (uploadError) {
        return sendJsonResponse(res, 400, {
          success: false,
          message: "Erreur lors de l'upload de l'image",
          error: uploadError.message
        });
      }

      const updateFields = { ...req.body };

      // Gestion de l'image uploadée
      if (req.file) {
        const newImagePath = `${req.protocol}://${req.get('host')}/uploads/users/${req.file.filename}`;
        updateFields.profilePicture = newImagePath;
        
        // Suppression de l'ancienne image
        try {
          const oldUser = await User.findById(userId).select('profilePicture').lean();
          if (oldUser?.profilePicture) {
            const filename = path.basename(oldUser.profilePicture);
            const oldImagePath = path.join(__dirname, '..', '..', 'uploads', 'users', filename);
            
            if (fs.existsSync(oldImagePath)) {
              fs.unlink(oldImagePath, (unlinkError) => {
                if (unlinkError) console.error('Erreur suppression ancienne image:', unlinkError);
              });
            }
          }
        } catch (fsError) {
          console.error('Erreur gestion fichiers:', fsError);
        }
      }

      // Protection des champs sensibles
      const protectedFields = [ 'role', 'veterinaireId', 'isActive'];
      const invalidUpdate = protectedFields.some(field => field in updateFields);
      
      if (invalidUpdate) {
        // Suppression de la nouvelle image si uploadée
        if (req.file) {
          const tempPath = path.join(__dirname, '..', '..', 'uploads', 'users', req.file.filename);
          if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
        }
        
        return sendJsonResponse(res, 403, {
          success: false,
          message: "Modification non autorisée pour certains champs"
        });
      }

      // Mise à jour de l'utilisateur
      const updatedUser = await User.findByIdAndUpdate(
        userId,
        updateFields,
        { 
          new: true,
          runValidators: true,
          select: '-password -refreshToken -loginAttempts -lockUntil'
        }
      );

      if (!updatedUser) {
        // Suppression de la nouvelle image si l'utilisateur n'existe pas
        if (req.file) {
          const tempPath = path.join(__dirname, '..', '..', 'uploads', 'users', req.file.filename);
          if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
        }
        if (updateFields.password) {
          const salt = await bcrypt.genSalt(10);
          updateFields.password = await bcrypt.hash(updateFields.password, salt);
        }

        return sendJsonResponse(res, 404, {
          success: false,
          message: "Utilisateur non trouvé"
        });
      }

      // Réponse réussie
      sendJsonResponse(res, 200, {
        success: true,
        message: "Profil mis à jour avec succès",
        user: {
          id: updatedUser._id,
          firstName: updatedUser.firstName,
          lastName: updatedUser.lastName,
          profilePicture: updatedUser.profilePicture,
          email: updatedUser.email,
          role: updatedUser.role
        }
      });

    } catch (error) {
      console.error("Erreur updateUser:", error);
      
      // Nettoyage des fichiers en cas d'erreur
      if (req.file) {
        try {
          const tempPath = path.join(__dirname, '..', '..', 'uploads', 'users', req.file.filename);
          if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
        } catch (cleanupError) {
          console.error('Erreur nettoyage fichier:', cleanupError);
        }
      }

      sendJsonResponse(res, 500, {
        success: false,
        message: error instanceof Error ? error.message : "Erreur serveur lors de la mise à jour",
        ...(process.env.NODE_ENV === 'development' && {
          error: error instanceof Error ? error.stack : undefined
        })
      });
    }
  });
};
export const deleteUser: ExpressController = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      res.status(400).json({ message: "ID utilisateur invalide" });
      return;
    }

    // 1. Récupérer l'utilisateur pour vérifier l'image
    const user = await UserService.getUserById(userId);
    if (!user) {
      res.status(404).json({ message: "Utilisateur non trouvé" });
      return;
    }

    // 2. Supprimer l'utilisateur
    const deletedUser = await UserService.deleteUser(userId);
    if (!deletedUser) {
      res.status(500).json({ message: "Échec de la suppression" });
      return;
    }

    // 3. Supprimer l'image si elle existe
    if (user.profilePicture) {
      const filename = user.profilePicture.split('/').pop();
      if (filename) {
        const filePath = path.join(__dirname, '..', 'uploads', 'users', filename);
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      }
    }

    // Envoyer la réponse sans retourner
    res.status(200).json({ 
      message: "Utilisateur supprimé avec succès",
      deletedUserId: userId
    });

  } catch (error) {
    console.error("Erreur:", error);
    res.status(500).json({
      message: "Erreur serveur",
      error: process.env.NODE_ENV === 'development' 
        ? error instanceof Error ? error.message : "Erreur inconnue"
        : undefined
    });
  }
};


export const getVeterinarians: ExpressController = async (req, res) => {
  try {
    const { 
      rating: ratingParam, 
      city,
      state,
      country, 
      services: servicesParam,
      firstName,
      lastName,
      page: pageParam = '1',
      sort = 'desc'
    } = req.query;

    // Parsing des paramètres
    const rating = ratingParam ? parseFloat(ratingParam as string) : undefined;
    const services = servicesParam ? (servicesParam as string).split(',') : undefined;
    const page = Math.max(1, parseInt(pageParam as string) || 1);
    const limit = 10;
    const sortOrder = sort === 'asc' ? 1 : -1;

    const filter: any = { role: UserRole.VETERINAIRE };

    // Filtrage par localisation (city, state, country) et nom (firstName, lastName)
    if (city || state || country || firstName || lastName) {
      filter.$and = [];

      if (city) filter.$and.push({ 'address.city': new RegExp(city as string, 'i') });
      if (state) filter.$and.push({ 'address.state': new RegExp(state as string, 'i') });
      if (country) filter.$and.push({ 'address.country': new RegExp(country as string, 'i') });
      if (firstName) filter.$and.push({ firstName: new RegExp(firstName as string, 'i') });
      if (lastName) filter.$and.push({ lastName: new RegExp(lastName as string, 'i') });
    }

    if (services?.length) {
      filter['details.services'] = { $in: services };
    }

    // Debug : Log du filtre généré pour vérifier la bonne structure
    console.log("Filtre généré : ", filter);

    // Pipeline d'agrégation pour calculer la moyenne des évaluations et le nombre de critiques
    const aggregationPipeline = [
      { $match: filter },
      {
        $lookup: {
          from: "ratings", // Assurez-vous que la collection s'appelle "ratings"
          localField: "_id",
          foreignField: "veterinarian", // Assurez-vous que ce champ existe dans le modèle Rating
          as: "ratings",
        },
      },
      {
        $addFields: {
          averageRating: {
            $cond: { 
              if: { $gt: [{ $size: "$ratings" }, 0] }, 
              then: { $avg: "$ratings.rating" }, 
              else: 0 
            }
          },
          reviewCount: { $size: "$ratings" }, // Nombre de critiques
        },
      },
      {
        $sort: { averageRating: sortOrder as 1 | -1, lastName: sortOrder as 1 | -1 }
      },
      {
        $project: {
          password: 0,
          refreshToken: 0,
          ratings: 0, // On ne retourne pas les détails des évaluations
        }
      },
      {
        $skip: (page - 1) * limit
      },
      {
        $limit: limit
      }
    ];

    // Exécution de l'agrégation
    const veterinarians = await User.aggregate(aggregationPipeline);

    // Récupérer le nombre total pour la pagination
    const totalCount = await User.countDocuments(filter);

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



export const getSecretariensByVeterinaire: RequestHandler = async (req, res, next) => {
  try {
    // Vérification de la connexion MongoDB
    if (!mongoose.connection?.readyState) {
      res.status(500).json({ 
        success: false,
        message: 'Database connection not established'
      });
      return;
    }

    const { veterinaireId } = req.params;

    // Validation de l'ID
    if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
      res.status(400).json({
        success: false,
        message: 'Invalid veterinarian ID format'
      });
      return;
    }

    const vetObjectId = new mongoose.Types.ObjectId(veterinaireId);

    // Vérification que le vétérinaire existe
    const vetExists = await User.exists({
      _id: vetObjectId,
      role: 'veterinaire'
    });

    if (!vetExists) {
      res.status(404).json({
        success: false,
        message: 'Veterinarian not found'
      });
      return;
    }

    // Recherche des secrétaires
    const secretariens = await User.find({
      role: 'secretaire',
      veterinaireId: vetObjectId,
      isActive: true
    })
      .select('_id firstName lastName email phoneNumber profilePicture createdAt')
      .sort({ lastName: 1, firstName: 1 })
      .lean();

    res.status(200).json({
      success: true,
      count: secretariens.length,
      data: secretariens
    });

  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      ...(process.env.NODE_ENV === 'development' && {
        error: error instanceof Error ? error.message : 'Unknown error'
      })
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

    // Pipeline d'agrégation amélioré
    const aggregationPipeline = [
      { 
        $match: { 
          _id: new mongoose.Types.ObjectId(userId),
          role: UserRole.VETERINAIRE 
        } 
      },
      {
        $lookup: {
          from: "reviews",
          localField: "_id",
          foreignField: "veterinarian",
          as: "reviews",
          pipeline: [
            {
              $group: {
                _id: "$user",  // Groupe par utilisateur distinct
                rating: { $first: "$rating" } // Prend juste la note (peu importe laquelle)
              }
            }
          ]
        }
      },
      {
        $addFields: {
          averageRating: {
            $cond: {
              if: { $gt: [{ $size: "$reviews" }, 0] },
              then: { $avg: "$reviews.rating" },
              else: 0
            }
          },
          totalReviews: { // Nombre total de reviews (tous utilisateurs confondus)
            $size: "$reviews"
          },
          uniqueReviewersCount: { // Nombre d'utilisateurs distincts ayant laissé un avis
            $size: "$reviews"
          },
          reviews: "$$REMOVE" // On supprime le tableau complet des reviews
        }
      },
      {
        $project: {
          password: 0,
          refreshToken: 0,
          // On conserve les nouveaux champs calculés
        }
      }
    ];

    const result = await User.aggregate(aggregationPipeline);

    if (!result.length) {
      sendJsonResponse(res, 404, { message: "Vétérinaire non trouvé" });
      return;
    }

    const vet = result[0];
    sendJsonResponse(res, 200, vet);
  } catch (error) {
    console.error("Erreur getVeterinaireById:", error);
    sendJsonResponse(res, 500, {
      message: error instanceof Error ? error.message : "Erreur serveur"
    });
  }
};
