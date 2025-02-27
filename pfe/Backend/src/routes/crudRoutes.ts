import express from "express";
import { updateUser, deleteUser, getUsersByRole, getUserById } from "../controllers/crudController"; // Ajout de l'importation de getUserById

const router = express.Router();


router.put("/update/:userId", updateUser);


router.delete("/delete/:userId", deleteUser);


router.get("/list/:role", getUsersByRole);


router.get("/users/:userId", getUserById); 

export default router;
