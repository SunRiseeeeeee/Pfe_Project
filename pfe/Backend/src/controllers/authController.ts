import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";
import User from "../models/User"; // 🔧 Ajout de l'import manquant

const validDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
const isValidTime = (time: string): boolean => /^([01]\d|2[0-3]):[0-5]\d$/.test(time);

const Signup = async (req: Request, res: Response, role: UserRole): Promise<void> => {
  const {
    firstName,
    lastName,
    username,
    email,
    password,
    phoneNumber,
    profilePicture = null,
    MapsLocation = null,
    description = null,
    services = [],
    workingHours = [],
    address = {}
  } = req.body;

  try {
    if (!firstName || !lastName || !username || !email || !password || !phoneNumber) {
      throw new Error("Tous les champs obligatoires doivent être remplis");
    }

    const extraDetails: Record<string, any> = {
      profilePicture,
      MapsLocation,
      description,
      details: {},
      reviews: []
    };

    if (address && typeof address === "object") {
      const { street, city, state, country } = address;
      const addressFields = { street, city, state, country };

      for (const [key, value] of Object.entries(addressFields)) {
        if (value !== undefined && typeof value !== "string") {
          throw new Error(`Le champ ${key} de l'adresse doit être une chaîne de caractères`);
        }
      }

      extraDetails.address = addressFields;
    }

    switch (role) {
      case UserRole.VETERINAIRE:
        if (!Array.isArray(services) || !services.every(s => typeof s === "string")) {
          throw new Error("Les services doivent être un tableau de chaînes");
        }

        if (!Array.isArray(workingHours)) {
          throw new Error("Les horaires de travail doivent être un tableau");
        }

        for (const slot of workingHours) {
          if (!slot.day || !slot.start || !slot.end) {
            throw new Error("Chaque horaire doit contenir les champs 'day', 'start' et 'end'");
          }

          if (!validDays.includes(slot.day)) {
            throw new Error(`Jour invalide: ${slot.day}`);
          }

          if (!isValidTime(slot.start) || !isValidTime(slot.end)) {
            throw new Error(`Heure invalide pour ${slot.day}. Format attendu: HH:MM`);
          }
        }

        extraDetails.details = { services, workingHours };
        extraDetails.rating = 0;
        break;

      case UserRole.SECRETAIRE:
        extraDetails.details = { workingHours };
        break;

      case UserRole.CLIENT:
        break;

      default:
        throw new Error("Rôle non valide");
    }

    const userData = {
      firstName,
      lastName,
      username,
      email,
      password,
      phoneNumber,
      role
    };

    const user = await UserService.createUser(userData, extraDetails);

    res.status(201).json({
      success: true,
      message: `${role} inscrit avec succès`,
      userId: user._id
    });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : "Erreur inconnue lors de l'inscription";
    console.error(`Erreur d'inscription (${role}):`, errorMessage);
    res.status(400).json({
      success: false,
      message: errorMessage
    });
  }
};

export const SignupClient = (req: Request, res: Response) => Signup(req, res, UserRole.CLIENT);
export const SignupVeterinaire = (req: Request, res: Response) => Signup(req, res, UserRole.VETERINAIRE);
export const SignupSecretaire = (req: Request, res: Response) => Signup(req, res, UserRole.SECRETAIRE);
export const SignupAdmin = (req: Request, res: Response) => Signup(req, res, UserRole.ADMIN);

export const Login = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;

<<<<<<< HEAD
=======
  // Validate input
>>>>>>> 0293d7c721f3dafaac814f15896fb21529867aca
  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
<<<<<<< HEAD
    const { accessToken, refreshToken } = await UserService.authenticateUser(username, password);
    console.log("🔑 Utilisateur connecté :", { username, accessToken, refreshToken });
    res.json({ message: "Connexion réussie", accessToken, refreshToken });
  } catch (error: unknown) {
    console.error("Erreur lors de la connexion :", error);
=======
    // Authenticate the user
    const { accessToken, refreshToken, user } = await UserService.authenticateUser(username, password);

    console.log("🔑 Utilisateur connecté :", { username, accessToken, refreshToken });

    // Return the access token, refresh token, and user details
    res.json({
      message: "Connexion réussie",
      accessToken,
      refreshToken,
      user: {
        id: user.id, // Include the user ID
        email: user.email,
      },
    });
  } catch (error: unknown) {
    // Handle authentication errors
>>>>>>> 0293d7c721f3dafaac814f15896fb21529867aca
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec de l'authentification" });
  }
};

export const RefreshAccessToken = async (req: Request, res: Response): Promise<void> => {
  const { refreshToken } = req.body;

  // Validate input
  if (!refreshToken) {
    res.status(400).json({ message: "Refresh token requis" });
    return;
  }

  try {
    // Refresh the access token
    const { accessToken } = await UserService.refreshAccessToken(refreshToken);
    res.json({ accessToken });
  } catch (error: unknown) {
    // Handle token refresh errors
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec du rafraîchissement du token" });
  }
};

export const Logout = async (req: Request, res: Response): Promise<void> => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    res.status(400).json({ message: "Refresh token requis" });
    return;
  }

  try {
    const user = await User.findOne({ refreshToken });
    if (!user) {
      res.status(403).json({ message: "Utilisateur non trouvé" });
      return;
    }

    user.refreshToken = null;
    await user.save();

    res.json({ message: "Déconnexion réussie" });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur lors de la déconnexion" });
  }
};
