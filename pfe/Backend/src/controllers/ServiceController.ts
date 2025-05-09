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
    const { name, description } = req.body;
    const imageFile = req.file;

    // Vérification des données
    if (!name && !description && !imageFile) {
      res.status(400).json({ 
        message: "Au moins un champ (nom, description ou image) doit être fourni pour la mise à jour" 
      });
      return;
    }

    // Récupération du service existant
    const existingService = await ServiceService.getServiceById(id);
    if (!existingService) {
      res.status(404).json({ message: "Service non trouvé" });
      return;
    }

    // Préparation des données de mise à jour
    const updateData: Partial<IServiceInput> = {
      ...(name && { name }),
      ...(description && { description }),
    };

    // Gestion de l'image
    if (imageFile) {
      try {
        // Suppression de l'ancienne image
        if (existingService.image) {
          await deleteExistingImage(existingService.image, req);
        }

        // Traitement de la nouvelle image
        const localPath = `/uploads/services/${imageFile.filename}`;
const imageUrl = buildImageUrl(req, localPath);
updateData.image = imageUrl;


      } catch (error) {
        console.error("Erreur de traitement de l'image:", error);
        res.status(500).json({ message: "Erreur lors du traitement de l'image" });
        return;
      }
    }

    // Mise à jour en base de données
    const updatedService = await ServiceService.updateService(id, updateData);
    
    if (!updatedService) {
      res.status(500).json({ message: "Échec de la mise à jour du service" });
      return;
    }

    // Réponse finale
    const responseData = {
      ...updatedService.toObject(),
      image: updateData.image || existingService.image
    };

    res.status(200).json(responseData);

  } catch (error) {
    console.error('Erreur dans updateService:', error);
    next(error);
  }
};

// Fonctions utilitaires (restent identiques)
async function deleteExistingImage(imageUrl: string, req: Request): Promise<void> {
  try {
    const basePath = path.join(__dirname, '..', '..', 'uploads', 'services');
    const filename = imageUrl.split('/uploads/services/')[1];
    
    if (filename) {
      const fullPath = path.join(basePath, filename);
      if (fs.existsSync(fullPath)) {
        await fs.promises.unlink(fullPath);
      }
    }
  } catch (error) {
    console.error("Erreur lors de la suppression de l'image existante:", error);
    throw error;
  }
}

async function processUploadedImage(file: Express.Multer.File, req: Request): Promise<string> {
  const uploadDir = path.join(__dirname, '..', '..', 'uploads', 'services');
  
  // Création du dossier si nécessaire
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }

  // Génération du nouveau nom de fichier
  const fileExt = path.extname(file.originalname);
  const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
  const newFilename = `service-${uniqueSuffix}${fileExt}`;
  const newPath = path.join(uploadDir, newFilename);

  // Déplacement du fichier
  await fs.promises.rename(file.path, newPath);

  // Retourne l'URL complète
  return `${req.protocol}://${req.get('host')}/uploads/services/${newFilename}`;
}

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
