import { Router } from "express";
import { SignupClient, SignupSecretaire, LoginClient, LoginAdmin, LoginSecretaire } from "../controllers/authController";

const router = Router();

// Routes d'inscription
router.post("/signup/client", SignupClient);
router.post("/signup/secretaire", SignupSecretaire);

// Routes de login
router.post("/login/client", LoginClient);
router.post("/login/admin", LoginAdmin); // Assurez-vous que l'admin existe dans ton système
router.post("/login/secretaire", LoginSecretaire);

export default router;
