import express from "express";
import { updateUser, deleteUser, getUsersByRole, getUserById } from "../controllers/crudController"; // Ajout de l'importation de getUserById

const router = express.Router();


/**
 * @swagger
 * /update/{userId}:
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
 *                 description: Nouveau prénom de l'utilisateur
 *                 example: "Ahmed"
 *               lastName:
 *                 type: string
 *                 description: Nouveau nom de famille de l'utilisateur
 *                 example: "Ben Ali"
 *               username:
 *                 type: string
 *                 description: Nouveau nom d'utilisateur
 *                 example: "ahmed_ben"
 *               email:
 *                 type: string
 *                 description: Nouvelle adresse email
 *                 example: "ahmed@example.com"
 *               phoneNumber:
 *                 type: string
 *                 description: Nouveau numéro de téléphone
 *                 example: "+21698765432"
 *               profilePicture:
 *                 type: string
 *                 format: binary
 *                 description: Nouvelle photo de profil (upload fichier)
 *               location:
 *                 type: string
 *                 description: Nouvelle localisation
 *                 example: "Tunis, Tunisie"
 *               details:
 *                 type: object
 *                 description: Informations spécifiques selon le rôle
 *                 properties:
 *                   specialty:
 *                     type: string
 *                     description: Spécialité du vétérinaire (si applicable)
 *                     example: "Chirurgie animale"
 *                   workingHours:
 *                     type: string
 *                     description: Horaires de travail du vétérinaire ou de la secrétaire
 *                     example: "09:00 - 17:00"
 *     responses:
 *       200:
 *         description: Utilisateur mis à jour avec succès
 *       400:
 *         description: Données invalides ou requête incorrecte
 *       404:
 *         description: Utilisateur non trouvé
 *       500:
 *         description: Erreur serveur
 */
router.put("/update/:userId", updateUser);



/**
 * @swagger
 * /delete/{userId}:
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
 *         description: ID invalide ou requête incorrecte
 *       404:
 *         description: Utilisateur non trouvé
 *       500:
 *         description: Erreur serveur
 */
router.delete("/delete/:userId", deleteUser);


/**
 * @swagger
 * /list/{role}:
 *   get:
 *     summary: Récupérer la liste des utilisateurs par rôle
 *     description: |
 *       Retourne une liste d'utilisateurs en fonction du rôle spécifié. 
 *       Le rôle doit être l'un des suivants : client, secretaire, veterinaire, admin.
 *     tags: [User]
 *     parameters:
 *       - in: path
 *         name: role
 *         required: true
 *         schema:
 *           type: string
 *           enum: [client, secretaire, veterinaire, admin]  # Liste des rôles valides
 *         description: Le rôle des utilisateurs à récupérer
 *     responses:
 *       200:
 *         description: Liste des utilisateurs récupérée avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/User'
 *             examples:
 *               users:
 *                 value:
 *                   - _id: "1234567890"
 *                     firstName: "Ahmed"
 *                     lastName: "Ben Ali"
 *                     username: "ahmed_ben"
 *                     email: "ahmed@example.com"
 *                     phoneNumber: "+21698765432"
 *                     role: "client"
 *                     profilePicture: "https://example.com/profile.jpg"
 *                   - _id: "0987654321"
 *                     firstName: "Ali"
 *                     lastName: "Ben Mohamed"
 *                     username: "ali_ben"
 *                     email: "ali@example.com"
 *                     phoneNumber: "+21612345678"
 *                     role: "veterinaire"
 *                     profilePicture: "https://example.com/profile2.jpg"
 *       400:
 *         description: |
 *           Requête incorrecte (ex: rôle invalide ou erreur lors de la récupération des utilisateurs)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   description: Message d'erreur
 *             examples:
 *               invalidRole:
 *                 value:
 *                   message: "Rôle invalide"
 *               error:
 *                 value:
 *                   message: "Erreur lors de la récupération des utilisateurs"
 *       404:
 *         description: Aucun utilisateur trouvé pour ce rôle
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   description: Message d'erreur
 *             example:
 *               message: "Aucun utilisateur trouvé pour ce rôle"
 *       500:
 *         description: Erreur serveur interne
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   description: Message d'erreur
 *             example:
 *               message: "Erreur serveur interne"
 */
router.get("/list/:role", getUsersByRole);



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
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 _id:
 *                   type: string
 *                   description: L'ID de l'utilisateur
 *                 firstName:
 *                   type: string
 *                   description: Le prénom de l'utilisateur
 *                 lastName:
 *                   type: string
 *                   description: Le nom de famille de l'utilisateur
 *                 username:
 *                   type: string
 *                   description: Le nom d'utilisateur
 *                 email:
 *                   type: string
 *                   description: L'adresse email de l'utilisateur
 *                 phoneNumber:
 *                   type: string
 *                   description: Le numéro de téléphone de l'utilisateur
 *                 role:
 *                   type: string
 *                   description: Le rôle de l'utilisateur
 *                 profilePicture:
 *                   type: string
 *                   description: L'URL de la photo de profil de l'utilisateur
 *         examples:
 *           application/json:
 *             value: 
 *               {
 *                 "_id": "1234567890",
 *                 "firstName": "Ahmed",
 *                 "lastName": "Ben Ali",
 *                 "username": "ahmed_ben",
 *                 "email": "ahmed@example.com",
 *                 "phoneNumber": "+21698765432",
 *                 "role": "client",
 *                 "profilePicture": "https://example.com/profile.jpg"
 *               }
 *       400:
 *         description: ID invalide ou requête incorrecte
 *       404:
 *         description: Utilisateur non trouvé
 *       500:
 *         description: Erreur serveur
 */
router.get("/users/:userId", getUserById);


export default router;
