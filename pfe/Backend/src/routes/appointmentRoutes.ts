import express, { Request, Response, NextFunction } from "express";
import asyncHandler from "express-async-handler"; // Ajout de asyncHandler pour gérer les erreurs asynchrones
import {
  createAppointment,
  getAppointments,
  getAppointmentById,
  getAppointmentsByClient,
  getAppointmentsByVeterinaire,
  updateAppointment,
  deleteAppointment,
  acceptAppointment,
  rejectAppointment,
} from "../controllers/appointmentController";
import { authenticateToken } from "../middlewares/authMiddleware";

const router = express.Router();

/**
 * @swagger
 * /appointments:
 *   post:
 *     summary: Créer un nouveau rendez-vous
 *     description: Permet à un utilisateur de prendre un rendez-vous
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               clientId:
 *                 type: string
 *               veterinaire:
 *                 type: string
 *               date:
 *                 type: string
 *                 format: date-time
 *               animalName:
 *                 type: string
 *               type:
 *                 type: string
 *                 enum: [domicile, cabinet]
 *     responses:
 *       201:
 *         description: Rendez-vous créé avec succès
 */
router.post("/", authenticateToken, asyncHandler(createAppointment)); // Mise à jour de la route ici

/**
 * @swagger
 * /appointments:
 *   get:
 *     summary: Obtenir tous les rendez-vous
 *     responses:
 *       200:
 *         description: Liste des rendez-vous récupérée avec succès
 */
router.get("/", asyncHandler(getAppointments));

/**
 * @swagger
 * /appointments/{id}:
 *   get:
 *     summary: Obtenir un rendez-vous par ID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID du rendez-vous
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Détails du rendez-vous récupérés avec succès
 */
router.get("/:id", asyncHandler(getAppointmentById));

/**
 * @swagger
 * /appointments/client/{clientId}:
 *   get:
 *     summary: Obtenir les rendez-vous d'un client
 *     parameters:
 *       - in: path
 *         name: clientId
 *         required: true
 *         description: ID du client
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des rendez-vous du client récupérée avec succès
 */
router.get("/client/:clientId", asyncHandler(getAppointmentsByClient));

/**
 * @swagger
 * /appointments/veterinarian/{veterinaire}:
 *   get:
 *     summary: Obtenir les rendez-vous des clients d'un vétérinaire
 *     parameters:
 *       - in: path
 *         name: veterinaire
 *         required: true
 *         description: ID du vétérinaire
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des rendez-vous récupérée avec succès
 */
router.get("/veterinarian/:veterinaire", asyncHandler(getAppointmentsByVeterinaire));

/**
 * @swagger
 * /appointments/{id}:
 *   put:
 *     summary: Mettre à jour un rendez-vous
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID du rendez-vous
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               date:
 *                 type: string
 *                 format: date-time
 *               animalName:
 *                 type: string
 *               type:
 *                 type: string
 *                 enum: [domicile, cabinet]
 *     responses:
 *       200:
 *         description: Rendez-vous mis à jour avec succès
 */
router.put("/:id", asyncHandler(updateAppointment));

/**
 * @swagger
 * /appointments/{id}:
 *   delete:
 *     summary: Supprimer un rendez-vous
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID du rendez-vous
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rendez-vous supprimé avec succès
 */
router.delete("/:id", asyncHandler(deleteAppointment));

/**
 * @swagger
 * /appointments/{id}/accept:
 *   put:
 *     summary: Accepter un rendez-vous
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID du rendez-vous
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rendez-vous accepté avec succès
 */
router.put("/:id/accept", asyncHandler(acceptAppointment));

/**
 * @swagger
 * /appointments/{id}/reject:
 *   put:
 *     summary: Refuser un rendez-vous
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID du rendez-vous
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rendez-vous refusé avec succès
 */
router.put("/:id/reject", asyncHandler(rejectAppointment));

export default router;
