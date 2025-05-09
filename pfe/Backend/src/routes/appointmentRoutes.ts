import express from "express";
import asyncHandler from "express-async-handler";
import { authenticateToken } from "../middlewares/authMiddleware";
import {
  createAppointment,
  getClientsWithAcceptedAppointmentsForVeterinaire,
  getAppointmentForVeterinaireById,
  getAppointmentForClientById,
  getAppointmentsByClient,
  getAppointmentsByVeterinaire,
  updateAppointment,
  deleteAppointment,
  acceptAppointment,
  rejectAppointment,
  getClientAnimalsWithAcceptedAppointments,
} from "../controllers/appointmentController";

const router = express.Router();



router.get("/veterinaire/:veterinaireId/clients", getClientsWithAcceptedAppointmentsForVeterinaire);
router.get("/veterinaire/:veterinaireId/client/:clientId/animals",getClientAnimalsWithAcceptedAppointments);
/**
 * @swagger
 * /appointments:
 *   post:
 *     summary: Créer un nouveau rendez-vous
 *     tags: [Appointments]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - clientId
 *               - veterinaire
 *               - date
 *               - animalName
 *               - type
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
router.post("/", authenticateToken, asyncHandler(createAppointment));

/**
 * @swagger
 * /appointments/veterinaire/{id}:
 *   get:
 *     summary: Obtenir un rendez-vous pour un vétérinaire
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID du rendez-vous
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Détails du rendez-vous pour le vétérinaire
 */
router.get("/veterinarian/:veterinarianId/:id", getAppointmentForVeterinaireById);

/**
 * @swagger
 * /appointments/client/{id}:
 *   get:
 *     summary: Obtenir un rendez-vous pour un client
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID du rendez-vous
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Détails du rendez-vous pour le client
 */
router.get("/client/appointment/:clientId/:id", getAppointmentForClientById);


/**
 * @swagger
 * /appointments/client/history/{clientId}:
 *   get:
 *     summary: Obtenir tous les rendez-vous d'un client
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: clientId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des rendez-vous du client récupérée avec succès
 */
router.get('/client/history/:clientId',getAppointmentsByClient);

/**
 * @swagger
 * /appointments/veterinaire/history/{veterinaireId}:
 *   get:
 *     summary: Obtenir tous les rendez-vous pour un vétérinaire
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: veterinaireId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des rendez-vous du vétérinaire récupérée avec succès
 */
router.get('/veterinaire/history/:veterinaireId', getAppointmentsByVeterinaire);


/**
 * @swagger
 * /appointments/{id}:
 *   put:
 *     summary: Mettre à jour un rendez-vous
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
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
router.put("/:id", authenticateToken, asyncHandler(updateAppointment));

/**
 * @swagger
 * /appointments/{id}:
 *   delete:
 *     summary: Supprimer un rendez-vous
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rendez-vous supprimé avec succès
 */
router.delete("/:id", deleteAppointment);

/**
 * @swagger
 * /appointments/{id}/accept:
 *   put:
 *     summary: Accepter un rendez-vous
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rendez-vous accepté avec succès
 */
router.put("/:id/accept", acceptAppointment);

/**
 * @swagger
 * /appointments/{id}/reject:
 *   put:
 *     summary: Refuser un rendez-vous
 *     tags: [Appointments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rendez-vous refusé avec succès
 */
router.put("/:id/reject",rejectAppointment);

export default router;
