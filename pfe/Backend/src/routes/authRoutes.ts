import { Router } from "express";
import {
  SignupClient,
  SignupSecretaire,
  SignupVeterinaire,
  SignupAdmin,
  Login,
  RefreshAccessToken,
  Logout,
} from "../controllers/authController";

const router = Router();

/**
 * @swagger
 * /signup/client:
 *   post:
 *     summary: Inscription d'un client
 *     tags: [Auth]
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
 *               password:
 *                 type: string
 *               phoneNumber:
 *                 type: string
 *               profilePicture:
 *                 type: string
 *                 format: binary
 *     responses:
 *       201:
 *         description: Utilisateur inscrit avec succès
 *       400:
 *         description: Erreur d'inscription
 */
router.post("/signup/client", SignupClient);

/**
 * @swagger
 * /signup/secretaire:
 *   post:
 *     summary: Inscription d'un secrétaire
 *     tags: [Auth]

 *     requestBody:
 *       required: true
 *       content:
 *        application/json:
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
 *               password:
 *                 type: string
 *               phoneNumber:
 *                 type: string
 *               workingHours:
 *                 type: string
 *     responses:
 *       201:
 *         description: Utilisateur inscrit avec succès
 *       400:
 *         description: Erreur d'inscription
 */
router.post("/signup/secretaire", SignupSecretaire);

/**
 * @swagger
 * /signup/veterinaire:
 *   post:
 *     summary: Inscription d'un vétérinaire
  *     tags: [Auth]

 *     requestBody:
 *       required: true
 *       content:
 *        application/json:
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
 *               password:
 *                 type: string
 *               phoneNumber:
 *                 type: string
 *               workingHours:
 *                 type: string
 *               profilePicture:
 *                 type: string
 *                 format: binary
 *     responses:
 *       201:
 *         description: Utilisateur inscrit avec succès
 *       400:
 *         description: Erreur d'inscription
 */
router.post("/signup/veterinaire", SignupVeterinaire);

/**
 * @swagger
 * /signup/admin:
 *   post:
 *     summary: Inscription d'un administrateur
  *     tags: [Auth]

 *     requestBody:
 *       required: true
 *       content:
 *        application/json:
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
 *               password:
 *                 type: string
 *               phoneNumber:
 *                 type: string
 *     responses:
 *       201:
 *         description: Utilisateur inscrit avec succès
 *       400:
 *         description: Erreur d'inscription
 */
router.post("/signup/admin", SignupAdmin);

/**
 * @swagger
 * /login:
 *   post:
 *     summary: Connexion utilisateur
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               username:
 *                 type: string
 *                 description: Nom d'utilisateur ou email
 *                 example: "john_doe"
 *               password:
 *                 type: string
 *                 format: password
 *                 description: Mot de passe de l'utilisateur
 *                 example: "P@ssw0rd!"
 *     responses:
 *       200:
 *         description: Connexion réussie
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 accessToken:
 *                   type: string
 *                   description: Token d'accès JWT
 *                 refreshToken:
 *                   type: string
 *                   description: Token de rafraîchissement JWT
 *       400:
 *         description: Requête invalide (données manquantes ou incorrectes)
 *       401:
 *         description: Échec d'authentification (identifiants invalides)
 */
router.post("/login", Login);

/**
 * @swagger
 * /refresh-token:
 *   post:
 *     summary: Rafraîchir le token d'accès
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               refreshToken:
 *                 type: string
 *                 description: Token de rafraîchissement valide
 *                 example: "eyJhbGciOiJIUzI1NiIsIn..."
 *     responses:
 *       200:
 *         description: Nouveau token d'accès généré avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 accessToken:
 *                   type: string
 *                   description: Nouveau token d'accès JWT
 *                   example: "eyJhbGciOiJIUzI1NiIsIn..."
 *       400:
 *         description: Requête invalide (token manquant ou incorrect)
 *       401:
 *         description: Token de rafraîchissement invalide ou expiré
 */
router.post("/refresh-token", RefreshAccessToken);


/**
 * @swagger
 * /logout:
 *   post:
 *     summary: Déconnexion utilisateur
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               userId:
 *                 type: string
 *                 description: ID de l'utilisateur à déconnecter
 *                 example: "65e9c0f4b3a3b15f48d7f2a1"
 *     responses:
 *       200:
 *         description: Déconnexion réussie
 *       400:
 *         description: Requête invalide (ID utilisateur manquant ou incorrect)
 *       401:
 *         description: L'utilisateur n'est pas authentifié
 */
router.post("/logout", Logout);


export default router;
