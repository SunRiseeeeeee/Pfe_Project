// 🌐 Import des modules principaux
import express from "express";
import dotenv from "dotenv";
import path from "path";
import cors from "cors";
import http from "http";
import { Server } from "socket.io";
import connectDB from "./config/db";
import { setupSwagger } from "./swaggerConfig";
import { socketAuthMiddleware } from "./middlewares/authMiddleware";
import { initializeSocket } from "./controllers/chatController";
import { startReminderCronJob } from "./services/notificationService";
import './websocket/websocket';


// 🚀 Initialisation de l'application et des variables
dotenv.config();
const app = express();
const port = process.env.PORT || 3000;

// 🔌 Création du serveur HTTP et du serveur Socket.IO
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

// 🌐 Middlewares globaux
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 🌐 Dossier statique pour les uploads
app.use('/uploads', express.static(path.join(__dirname, 'services', 'uploads')));

// 🔄 Connexion à la base de données MongoDB
connectDB()
  .then(() => {
    console.log("✅ Connecté à MongoDB");
    startReminderCronJob(io); // 🔔 Démarrage du cron job pour les notifications
  })
  .catch((err) => console.error("❌ Erreur de connexion MongoDB :", err));

// 📌 Import dynamique des routes
import authRoutes from "./routes/authRoutes";
import crudRoutes from "./routes/crudRoutes";
import animalRoutes from "./routes/animalRoutes";
import appointmentRoutes from "./routes/appointmentRoutes";
import serviceRoutes from "./routes/serviceRoutes";
import ReviewRatingRoutes from "./routes/ReviewRatingRoutes";
import animalFicheRoutes from "./routes/animalFicheRoutes";
import postRoutes from "./routes/postRoutes";
import chatRoutes from "./routes/chatRoutes";
import notificationRoutes from "./routes/notificationRoutes";

// 🗂️ Montée des routes
app.use("/api/auth", authRoutes);
app.use("/api/users", crudRoutes);
app.use("/api/animals", animalRoutes);
app.use("/api/animal-fiche", animalFicheRoutes);
app.use("/api/appointments", appointmentRoutes);
app.use("/api/services", serviceRoutes);
app.use("/api/reviews", ReviewRatingRoutes);
app.use("/api/posts", postRoutes);
app.use("/api/chat", chatRoutes);
app.use("/api/notifications", notificationRoutes);

// 🔌 Initialisation du WebSocket
initializeSocket(io);
io.use(socketAuthMiddleware);

io.on("connection", (socket) => {
  console.log(`🔗 Utilisateur connecté: ${socket.user.id}`);
  socket.join(socket.user.id.toString());

  socket.on("disconnect", () => {
    console.log(`❌ Utilisateur déconnecté: ${socket.user.id}`);
  });
});

// 📑 Documentation Swagger
setupSwagger(app);

// 🚨 Gestion globale des erreurs
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

// 🚀 Démarrage du serveur
server.listen(port, () => {
  console.log(`🌐 Serveur démarré sur http://localhost:${port}`);
});
