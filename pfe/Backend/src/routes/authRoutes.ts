import { Router } from "express";
import {
  signupClient,
  signupVeterinaire,
  signupAdmin,
  loginHandler,
  refreshTokenHandler,
  resetPassword,

  forgetPassword,
  logoutHandler,
} from "../controllers/authController";
import { signupSecretaire } from "../controllers/authController"; // adapte le chemin si besoin




const router = Router();

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Authentication management
 */
router.post("/reset-password", resetPassword);

router.post("/forget-password", forgetPassword);
/**
 * @swagger
 * components:
 *   schemas:
 *     UserSignup:
 *       type: object
 *       required:
 *         - firstName
 *         - lastName
 *         - username
 *         - email
 *         - password
 *         - phoneNumber
 *       properties:
 *         firstName:
 *           type: string
 *         lastName:
 *           type: string
 *         username:
 *           type: string
 *         email:
 *           type: string
 *           format: email
 *         password:
 *           type: string
 *           minLength: 8
 *         phoneNumber:
 *           type: string
 *     Login:
 *       type: object
 *       required:
 *         - username
 *         - password
 *       properties:
 *         username:
 *           type: string
 *         password:
 *           type: string
 *     TokenResponse:
 *       type: object
 *       properties:
 *         accessToken:
 *           type: string
 *         refreshToken:
 *           type: string
 *     AuthResponse:
 *       allOf:
 *         - $ref: '#/components/schemas/TokenResponse'
 *         - type: object
 *           properties:
 *             user:
 *               type: object
 *               properties:
 *                 id:
 *                   type: string
 *                 role:
 *                   type: string
 *                 firstName:
 *                   type: string
 *                 lastName:
 *                   type: string
 *                 email:
 *                   type: string
 *                 username:
 *                   type: string
 *                 phoneNumber:
 *                   type: string
 */

/**
 * @swagger
 * /auth/signup/client:
 *   post:
 *     summary: Register a new client
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UserSignup'
 *     responses:
 *       201:
 *         description: Client registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Validation error or missing data
 *       409:
 *         description: User already exists
 *       500:
 *         description: Server error
 */
router.post("/signup/client", signupClient);

/**
 * @swagger
 * /auth/signup/secretaire/{veterinaireId}:
 *   post:
 *     summary: Register a new secretary under a specific veterinarian
 *     tags: [Auth]
 *     parameters:
 *       - in: path
 *         name: veterinaireId
 *         required: true
 *         schema:
 *           type: string
 *         description: The ID of the veterinarian creating the secretary account
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UserSignup'
 *     responses:
 *       201:
 *         description: Secretary registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Validation error or missing data
 *       409:
 *         description: User already exists
 *       500:
 *         description: Server error
 */
router.post("/signup/secretaire/:veterinaireId", signupSecretaire);


/**
 * @swagger
 * /auth/signup/veterinaire:
 *   post:
 *     summary: Register a new veterinarian
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             allOf:
 *               - $ref: '#/components/schemas/UserSignup'
 *               - type: object
 *                 properties:
 *                   specialization:
 *                     type: string
 *                   workingHours:
 *                     type: array
 *                     items:
 *                       type: object
 *                       properties:
 *                         day:
 *                           type: string
 *                         start:
 *                           type: string
 *                         end:
 *                           type: string
 *     responses:
 *       201:
 *         description: Veterinarian registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Validation error or missing data
 *       409:
 *         description: User already exists
 *       500:
 *         description: Server error
 */
router.post("/signup/veterinaire", signupVeterinaire);

/**
 * @swagger
 * /auth/signup/admin:
 *   post:
 *     summary: Register a new admin
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UserSignup'
 *     responses:
 *       201:
 *         description: Admin registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Validation error or missing data
 *       409:
 *         description: User already exists
 *       500:
 *         description: Server error
 */
router.post("/signup/admin", signupAdmin);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: User login
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Login'
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 *       400:
 *         description: Missing or invalid credentials
 *       401:
 *         description: Invalid credentials
 *       403:
 *         description: Account locked
 *       500:
 *         description: Server error
 */
router.post("/login", loginHandler);

/**
 * @swagger
 * /auth/refresh-token:
 *   post:
 *     summary: Refresh access token
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
 *     responses:
 *       200:
 *         description: Token refreshed successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TokenResponse'
 *       400:
 *         description: Missing refresh token
 *       401:
 *         description: Invalid or expired refresh token
 *       500:
 *         description: Server error
 */
router.post("/refresh-token", refreshTokenHandler);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: User logout
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */
router.post("/logout", logoutHandler);

export default router;
