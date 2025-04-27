import { Router } from "express";
import { createService, getAllServices, getServiceById, updateService, deleteService } from "../controllers/ServiceController";

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
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Service'
 *     responses:
 *       201:
 *         description: Service créé avec succès
 */
router.post("/", createService);

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
 *     parameters:
 *       - in: path
 *         name: id
 *         schema:
 *           type: string
 *         required: true
 *         description: ID du service à mettre à jour
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Service'
 *     responses:
 *       200:
 *         description: Service mis à jour
 *       404:
 *         description: Service non trouvé
 */
router.put("/:id", updateService);

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
