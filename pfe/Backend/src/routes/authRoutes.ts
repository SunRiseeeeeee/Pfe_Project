import { Router } from "express";
import {
  signupClient,
  signupSecretaire,
  signupVeterinaire,
  signupAdmin,
  login,
  refreshAccessToken,
  logout,
} from "../controllers/authController";

const router = Router();

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Gestion de l'authentification
 */

/**
 * @swagger
 * /auth/signup/client:
 *   post:
 *     summary: Inscription d'un client
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/ClientSignup'
 *     responses:
 *       201:
 *         description: Client inscrit avec succès
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Erreur de validation ou données manquantes
 *       500:
 *         description: Erreur serveur
 */
router.post("/signup/client", signupClient);

/**
 * @swagger
 * /auth/signup/secretaire:
 *   post:
 *     summary: Inscription d'un secrétaire
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/SecretaireSignup'
 *     responses:
 *       201:
 *         description: Secrétaire inscrit avec succès
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Erreur de validation ou données manquantes
 *       500:
 *         description: Erreur serveur
 */
router.post("/signup/secretaire", signupSecretaire);

/**
 * @swagger
 * /auth/signup/veterinaire:
 *   post:
 *     summary: Inscription d'un vétérinaire
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/VeterinaireSignup'
 *     responses:
 *       201:
 *         description: Vétérinaire inscrit avec succès
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Erreur de validation ou données manquantes
 *       500:
 *         description: Erreur serveur
 */
router.post("/signup/veterinaire", signupVeterinaire);

/**
 * @swagger
 * /auth/signup/admin:
 *   post:
 *     summary: Inscription d'un administrateur
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/AdminSignup'
 *     responses:
 *       201:
 *         description: Administrateur inscrit avec succès
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Erreur de validation ou données manquantes
 *       500:
 *         description: Erreur serveur
 */
router.post("/signup/admin", signupAdmin);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Connexion utilisateur
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Login'
 *     responses:
 *       200:
 *         description: Connexion réussie
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/LoginResponse'
 *       400:
 *         description: Données manquantes ou invalides
 *       401:
 *         description: Identifiants incorrects
 *       500:
 *         description: Erreur serveur
 */
router.post("/login", login);

/**
 * @swagger
 * /auth/refresh-token:
 *   post:
 *     summary: Rafraîchir le token d'accès
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/RefreshToken'
 *     responses:
 *       200:
 *         description: Token rafraîchi avec succès
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TokenResponse'
 *       400:
 *         description: Token manquant ou invalide
 *       401:
 *         description: Token expiré ou non autorisé
 *       500:
 *         description: Erreur serveur
 */
router.post("/refresh-token", refreshAccessToken);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Déconnexion utilisateur
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Logout'
 *     responses:
 *       200:
 *         description: Déconnexion réussie
 *       400:
 *         description: Token manquant ou invalide
 *       401:
 *         description: Non autorisé
 *       500:
 *         description: Erreur serveur
 */
router.post("/logout", logout);

export default router;
