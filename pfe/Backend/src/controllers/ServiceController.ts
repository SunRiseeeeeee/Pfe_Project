// src/controllers/ServiceController.ts

import { Request, Response, NextFunction } from "express";
import path from "path";
import fs from "fs";
import { ServiceService, IServiceInput } from "../services/serviceService";
import Service from "../models/Service";

// Etendre express.Request pour inclure multer.file
declare global {
  namespace Express {
    interface Request {
      file?: Express.Multer.File;
    }
  }
}

// Helper pour construire l'URL d'image absolue
const buildImageUrl = (req: Request, imagePath?: string): string | undefined => {
  if (!imagePath) return undefined;
  if (imagePath.startsWith("http://") || imagePath.startsWith("https://")) {
    return imagePath;
  }
  const baseUrl = process.env.BASE_URL ?? `${req.protocol}://${req.get("host")}`;
  return `${baseUrl}${imagePath}`;
};

/**
 * Crée un nouveau service
 */
export const createService = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { name, description } = req.body as { name: string; description?: string };
    const localPath = req.file ? `/uploads/services/${req.file.filename}` : undefined;
    const imageUrl = buildImageUrl(req, localPath);

    const input: IServiceInput = { name, description, image: imageUrl };
    const created = await ServiceService.createService(input);

    res.status(201).json(created);
  } catch (error) {
    next(error);
  }
};

/**
 * Récupère tous les services
 */
export const getAllServices = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const services = await ServiceService.getAllServices();
    const results = services.map(s => {
      const obj = s.toObject();
      (obj as any).image = buildImageUrl(req, obj.image as string);
      return obj;
    });
    res.json(results);
  } catch (error) {
    next(error);
  }
};

/**
 * Récupère un service par ID
 */
export const getServiceById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const service = await ServiceService.getServiceById(id);
    if (!service) {
      res.status(404).json({ message: "Service non trouvé" });
      return;
    }
    const obj = service.toObject();
    (obj as any).image = buildImageUrl(req, obj.image as string);
    res.json(obj);
  } catch (error) {
    next(error);
  }
};

/**
 * Met à jour un service existant
 */
export const updateService = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    
    // Récupération des champs textuels depuis form-data
    const name = req.body.name ? String(req.body.name) : undefined;
    const description = req.body.description ? String(req.body.description) : undefined;
    const imageFile = req.file; // Fichier uploadé

    // Debug: afficher les données reçues
    console.log('Données reçues:', { name, description, file: imageFile?.filename });

    // Vérification qu'il y a bien des données à mettre à jour
    if (!name && !description && !imageFile) {
      res.status(400).json({ message: "Aucune donnée valide fournie pour la mise à jour" });
      return;
    }

    // Récupération du service existant
    const existingService = await ServiceService.getServiceById(id);
    if (!existingService) {
      res.status(404).json({ message: "Service non trouvé" });
      return;
    }

    // Préparation des données de mise à jour
    const updateData: Partial<IServiceInput> = {};
    if (name) updateData.name = name;
    if (description) updateData.description = description;

    // Gestion de l'image si un fichier est fourni
    if (imageFile) {
      // Suppression de l'ancienne image si elle existe
      if (existingService.image) {
        try {
          const imagePath = existingService.image.split('/uploads/services/')[1];
          const fullPath = path.join(__dirname, '../uploads/services', imagePath);
          if (fs.existsSync(fullPath)) {
            fs.unlinkSync(fullPath);
          }
        } catch (error) {
          console.error("Erreur lors de la suppression de l'ancienne image:", error);
        }
      }

      // Génération d'un nouveau nom de fichier
      const newFilename = `service-${Date.now()}-${imageFile.originalname}`;
      const uploadDir = path.join(__dirname, '../uploads/services');

      // Création du dossier s'il n'existe pas
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
      }

      // Déplacement du fichier uploadé
      const newPath = path.join(uploadDir, newFilename);
      await fs.promises.rename(imageFile.path, newPath);

      // Mise à jour du chemin de l'image
      updateData.image = `${req.protocol}://${req.get('host')}/uploads/services/${newFilename}`;
    }

    // Mise à jour du service dans la base de données
    const updatedService = await ServiceService.updateService(id, updateData);
    
    if (!updatedService) {
      res.status(500).json({ message: "Échec de la mise à jour du service" });
      return;
    }

    // Réponse avec le service mis à jour
    res.status(200).json({
      ...updatedService.toObject(),
      image: updateData.image || existingService.image
    });

  } catch (error) {
    console.error('Erreur dans updateService:', error);
    next(error);
  }
};
/**
 * Supprime un service par ID
 */
export const deleteService = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const existing = await ServiceService.getServiceById(id);
    if (!existing) {
      res.status(404).json({ message: "Service non trouvé" });
      return;
    }

    if (existing.image) {
      const local = existing.image.replace(new RegExp(`^${req.protocol}://${req.get("host")}`), '');
      const imgPath = path.join(__dirname, '..', 'services', 'uploads', 'services', path.basename(local));
      fs.unlink(imgPath, err => err && console.error('Erreur suppression image :', err));
    }

    await ServiceService.deleteService(id);
    res.json({ message: "Service supprimé" });
  } catch (error) {
    next(error);
  }
};
