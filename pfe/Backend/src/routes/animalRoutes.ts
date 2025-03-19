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
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         description: ID de l'utilisateur
 *         schema:
 *           type: string
 *     responses:
 *       201:
 *         description: Animal créé avec succès
 */
router.post("/users/:userId/animals", asyncHandler(createAnimal));

/**
 * @swagger
 * /users/{userId}/animals:
 *   get:
 *     summary: Obtenir la liste des animaux d'un utilisateur
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
router.get("/users/:userId/animals", asyncHandler(getAnimalsByUser));

/**
 * @swagger
 * /users/{userId}/animals/{animalId}:
 *   get:
 *     summary: Obtenir les détails d'un animal spécifique
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
router.get("/users/:userId/animals/:animalId", asyncHandler(getAnimalById));

/**
 * @swagger
 * /users/{userId}/animals/{animalId}:
 *   put:
 *     summary: Mettre à jour un animal
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
 *         description: Animal mis à jour avec succès
 */
router.put("/users/:userId/animals/:animalId", asyncHandler(updateAnimal));

/**
 * @swagger
 * /users/{userId}/animals/{animalId}:
 *   delete:
 *     summary: Supprimer un animal
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
router.delete("/users/:userId/animals/:animalId", asyncHandler(deleteAnimal));

export default router;
