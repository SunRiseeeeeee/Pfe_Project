import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import connectDB from "./config/db";
import authRoutes from "./routes/authRoutes";
import crudRoutes from "./routes/crudRoutes"; // Ajout des routes utilisateur

dotenv.config();
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Connexion à MongoDB
connectDB()
  
  .catch((err) => console.error(" Erreur de connexion MongoDB :", err));

// Routes API
app.use("/api/auth", authRoutes);
app.use("/api/users", crudRoutes); // Ajout des routes utilisateur

// Middleware de gestion des erreurs globales
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(" Erreur détectée :", err.message);
  res.status(err.status || 500).json({ message: err.message || "Erreur interne du serveur" });
});

app.listen(port, () => {
  console.log(` Serveur démarré sur http://localhost:${port}`);
});
