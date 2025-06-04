import express from "express";
import asyncHandler from "express-async-handler";
import {
  
  createAnimal,
  getAnimalsByUser,
  getAnimalById,
  updateAnimal,
  deleteAnimal,
} from "../controllers/animalController";

const router = express.Router();

/**
 * @swagger
 * /users/{userId}/animals:
 *   post:
 *     summary: Créer un nouvel animal
 *     tags: [Animals]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         description: ID de l'utilisateur
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 description: Nom de l'animal
 *               species:
 *                 type: string
 *                 description: Espèce de l'animal
 *     responses:
 *       201:
 *         description: Animal créé avec succès
 */
router.post("/:userId/animals",createAnimal);

/**
 * @swagger
 * /users/{userId}/animals:
 *   get:
 *     summary: Obtenir la liste des animaux d'un utilisateur
 *     tags: [Animals]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         description: ID de l'utilisateur
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des animaux récupérée avec succès
 */
router.get("/:userId/animals", asyncHandler(getAnimalsByUser));

/**
 * @swagger
 * /users/{userId}/animals/{animalId}:
 *   get:
 *     summary: Obtenir les détails d'un animal spécifique
 *     tags: [Animals]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         description: ID de l'utilisateur
 *         schema:
 *           type: string
 *       - in: path
 *         name: animalId
 *         required: true
 *         description: ID de l'animal
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Détails de l'animal récupérés avec succès
 */
router.get("/:userId/animals/:animalId", asyncHandler(getAnimalById));

/**
 * @swagger
 * /users/{userId}/animals/{animalId}:
 *   put:
 *     summary: Mettre à jour un animal
 *     tags: [Animals]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         description: ID de l'utilisateur
 *         schema:
 *           type: string
 *       - in: path
 *         name: animalId
 *         required: true
 *         description: ID de l'animal
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 description: Nouveau nom de l'animal
 *               species:
 *                 type: string
 *                 description: Nouvelle espèce de l'animal
 *     responses:
 *       200:
 *         description: Animal mis à jour avec succès
 */
router.put("/:userId/animals/:animalId", asyncHandler(updateAnimal));

/**
 * @swagger
 * /users/{userId}/animals/{animalId}:
 *   delete:
 *     summary: Supprimer un animal
 *     tags: [Animals]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         description: ID de l'utilisateur
 *         schema:
 *           type: string
 *       - in: path
 *         name: animalId
 *         required: true
 *         description: ID de l'animal
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Animal supprimé avec succès
 */
router.delete("/:userId/animals/:animalId", asyncHandler(deleteAnimal));

export default router;