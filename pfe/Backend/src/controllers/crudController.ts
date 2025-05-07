import { Request, Response, NextFunction } from "express";
import { UserService } from "../services/userService";
import User, { UserRole } from "../models/User";
import mongoose from "mongoose";
import { userUpload } from '../services/userMulterConfig';
import path from "path";
import fs from 'fs';



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
      const protectedFields = ['email', 'role', 'password', 'veterinaireId', 'isActive'];
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
      sendJsonResponse(res, 400, { message: "ID utilisateur invalide" });
      return;
    }

    const deletedUser = await UserService.deleteUser(userId);
    if (!deletedUser) {
      sendJsonResponse(res, 404, { message: "Utilisateur non trouvé" });
      return;
    }

    sendJsonResponse(res, 200, { message: "Utilisateur supprimé définitivement avec succès" });
  } catch (error) {
    console.error("Erreur deleteUser:", error);
    sendJsonResponse(res, 500, {
      message: "Erreur lors de la suppression de l'utilisateur",
      error: error instanceof Error ? error.message : "Erreur inconnue",
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