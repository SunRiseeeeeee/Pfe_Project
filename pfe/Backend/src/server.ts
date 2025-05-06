// src/server.ts
import express from "express";
import dotenv from "dotenv";
import path from "path";
import cors from "cors";
import connectDB from "./config/db";
import authRoutes from "./routes/authRoutes";
import crudRoutes from "./routes/crudRoutes";         // routes utilisateurs (CRUD)
import animalRoutes from "./routes/animalRoutes";     // routes animaux
import appointmentRoutes from "./routes/appointmentRoutes";
import serviceRoutes from "./routes/serviceRoutes";   // routes services
import { setupSwagger } from "./swaggerConfig";

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Middlewares globaux
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connexion à MongoDB
connectDB()
  .then(() => console.log("Connecté à MongoDB"))
  .catch(err => console.error("❌ Erreur de connexion MongoDB :", err));

// Montée des routes
app.use('/uploads', express.static(path.join(__dirname, 'services', 'uploads')));

app.use("/api/auth", authRoutes);
app.use("/api/users", crudRoutes);
app.use("/api/animals", animalRoutes);          // Routes pour animaux corrigées
app.use("/api/appointments", appointmentRoutes);
app.use("/api/services", serviceRoutes);        // Nouvelle route pour services

// Documentation Swagger
setupSwagger(app);

// Gestion globale des erreurs
app.use(
  (
    err: any,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction
  ) => {
    console.error("💥 Erreur détectée :", err.message);
    res
      .status(err.status || 500)
      .json({ message: err.message || "Erreur interne du serveur" });
  }
);

app.listen(port, () => {
  console.log(`🚀 Serveur démarré sur http://localhost:${port}`);
});
