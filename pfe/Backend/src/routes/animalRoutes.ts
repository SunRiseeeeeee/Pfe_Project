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

router.post("/users/:userId/animals", asyncHandler(createAnimal));
router.get("/users/:userId/animals", asyncHandler(getAnimalsByUser));
router.get("/users/:userId/animals/:animalId", asyncHandler(getAnimalById));
router.put("/users/:userId/animals/:animalId", asyncHandler(updateAnimal));
router.delete("/users/:userId/animals/:animalId", asyncHandler(deleteAnimal));

export default router;
