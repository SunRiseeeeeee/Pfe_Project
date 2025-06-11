import { Router } from "express";
import {
  createService,
  getAllServices,
  getServiceById,
  updateService,
  deleteService,
} from "../controllers/ServiceController";
import multer from "multer";

// Configuration de Multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "C:/Users/baade/Documents/GitHub/Pfe_Project/pfe/Backend/src/services/uploads/services");
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + "-" + file.originalname);
  },
});

const serviceUpload = multer({ storage });

const router = Router();

/**
 * @swagger
 * tags:
 *   name: Services
 *   description: API pour gérer les services
 */

/**
 * @swagger
 * /api/services:
 *   post:
 *     summary: Création d'un nouveau service
 *     tags: [Services]
 *     consumes:
 *       - multipart/form-data
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *       201:
 *         description: Service créé avec succès
 */
router.post("/", serviceUpload.single("image"), createService);

/**
 * @swagger
 * /api/services:
 *   get:
 *     summary: Récupère tous les services
 *     tags: [Services]
 *     responses:
 *       200:
 *         description: Liste des services
 */
router.get("/", getAllServices);

/**
 * @swagger
 * /api/services/{id}:
 *   get:
 *     summary: Récupère un service par ID
 *     tags: [Services]
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: string
 *         required: true
 *         description: ID du service
 *     responses:
 *       200:
 *         description: Service trouvé
 *       404:
 *         description: Service non trouvé
 */
router.get("/:id", getServiceById);

/**
 * @swagger
 * /api/services/{id}:
 *   put:
 *     summary: Met à jour un service existant
 *     tags: [Services]
 *     consumes:
 *       - multipart/form-data
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: string
 *         required: true
 *         description: ID du service à mettre à jour
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Service mis à jour
 *       400:
 *         description: Données invalides
 *       404:
 *         description: Service non trouvé
 */
router.put("/:id", serviceUpload.single("image"), updateService);

/**
 * @swagger
 * /api/services/{id}:
 *   delete:
 *     summary: Supprime un service par ID
 *     tags: [Services]
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: string
 *         required: true
 *         description: ID du service à supprimer
 *     responses:
 *       200:
 *         description: Service supprimé
 *       404:
 *         description: Service non trouvé
 */
router.delete("/:id", deleteService);

export default router;
