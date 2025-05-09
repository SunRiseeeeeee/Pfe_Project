import express from "express";
import {
  updateUser,
  deleteUser,
  getVeterinarians,
  getVeterinaireById,
  
  getUserById
} from "../controllers/crudController";
import { getSecretariensByVeterinaire } from '../controllers/crudController';

const router = express.Router();

/**
 * @swagger
 * /veterinarians:
 *   get:
 *     summary: Récupérer tous les vétérinaires
 *     tags: [User]
 *     responses:
 *       200:
 *         description: Liste des vétérinaires récupérée avec succès
 *       404:
 *         description: Aucun vétérinaire trouvé
 *       500:
 *         description: Erreur serveur
 */
router.get("/veterinarians", getVeterinarians);
// Route pour récupérer les secrétaires d'un vétérinaire par son ID
router.get('/veterinaire/:veterinaireId/secretariens', getSecretariensByVeterinaire);
/**
 * @swagger
 * /users/{userId}:
 *   get:
 *     summary: Récupérer un utilisateur par son ID
 *     tags: [User]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: L'ID de l'utilisateur à récupérer
 *     responses:
 *       200:
 *         description: Utilisateur récupéré avec succès
 *       400:
 *         description: ID invalide ou requête incorrecte
 *       404:
 *         description: Utilisateur non trouvé
 *       500:
 *         description: Erreur serveur
 */
router.get("/:userId", getUserById);

/**
 * @swagger
 * /users/{userId}:
 *   put:
 *     summary: Mettre à jour les informations d'un utilisateur
 *     tags: [User]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: L'ID de l'utilisateur à mettre à jour
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *               username:
 *                 type: string
 *               email:
 *                 type: string
 *               phoneNumber:
 *                 type: string
 *               profilePicture:
 *                 type: string
 *               MapsLocation:
 *                 type: string
 *               details:
 *                 type: object
 *                 properties:
 *                   services:
 *                     type: string
 *                   workingHours:
 *                     type: string
 *     responses:
 *       200:
 *         description: Utilisateur mis à jour avec succès
 *       400:
 *         description: Données invalides
 *       404:
 *         description: Utilisateur non trouvé
 *       500:
 *         description: Erreur serveur
 */
router.put("/:userId", updateUser);

/**
 * @swagger
 * /users/{userId}:
 *   delete:
 *     summary: Supprimer un utilisateur
 *     tags: [User]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: L'ID de l'utilisateur à supprimer
 *     responses:
 *       200:
 *         description: Utilisateur supprimé avec succès
 *       400:
 *         description: ID invalide
 *       404:
 *         description: Utilisateur non trouvé
 *       500:
 *         description: Erreur serveur
 */
router.delete("/:userId", deleteUser);

router.get("/veterinarians/:userId", getVeterinaireById);


export default router;
