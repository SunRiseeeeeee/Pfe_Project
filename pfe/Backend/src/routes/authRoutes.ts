import { Router } from "express";
import {
  SignupClient,
  SignupSecretaire,
  SignupVeterinaire,
  SignupAdmin,
  LoginClient,
  LoginVeterinaire,
  LoginAdmin,
  LoginSecretaire,
} from "../controllers/authController";

const router = Router();

// Routes d'inscription
router.post("/signup/client", SignupClient);
router.post("/signup/secretaire", SignupSecretaire);
router.post("/signup/veterinaire", SignupVeterinaire);
router.post("/signup/admin", SignupAdmin);

// Routes de login
router.post("/login/client", LoginClient);
router.post("/login/veterinaire", LoginVeterinaire);
router.post("/login/admin", LoginAdmin);
router.post("/login/secretaire", LoginSecretaire);

export default router;
