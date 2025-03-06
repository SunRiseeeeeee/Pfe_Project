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

// Routes d'inscription
router.post("/signup/client", SignupClient);
router.post("/signup/secretaire", SignupSecretaire);
router.post("/signup/veterinaire", SignupVeterinaire);
router.post("/signup/admin", SignupAdmin);

// Route de login
router.post("/login", Login);

// Route pour rafraîchir le token d'accès
router.post("/refresh-token", RefreshAccessToken);

// Route pour la déconnexion
router.post("/logout", Logout);

export default router;