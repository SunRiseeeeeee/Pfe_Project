import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";



// Liste des jours valides
const validDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

// Vérifie le format HH:MM (24h)
const isValidTime = (time: string): boolean => /^([01]\d|2[0-3]):[0-5]\d$/.test(time);
// Inscription d'un utilisateur (générique pour tous les rôles)
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
    services = [],  // tableau vide par défaut
    workingHours = [] // tableau vide par défaut
  } = req.body;

  try {
    // Validation des champs obligatoires
    if (!firstName || !lastName || !username || !email || !password || !phoneNumber) {
      throw new Error('Tous les champs obligatoires doivent être remplis');
    }

    const extraDetails: Record<string, any> = {
      profilePicture,
      MapsLocation,
      description,
      details: {},
      reviews: []
    };

    // Traitement spécifique selon le rôle
    if (role === UserRole.VETERINAIRE) {
      // Validation des services
      if (!Array.isArray(services) || !services.every(s => typeof s === "string")) {
        throw new Error("Les services doivent être un tableau de chaînes");
      }

      // Validation des horaires
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

    } else if (role === UserRole.SECRETAIRE) {
      extraDetails.details = { workingHours };
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

    // Création de l'utilisateur
    const user = await UserService.createUser(userData, extraDetails);

    res.status(201).json({
      success: true,
      message: `${role} inscrit avec succès`,
      userId: user._id
    });

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : "Erreur inconnue lors de l'inscription";
    console.error(`Erreur d'inscription (${role}):`, error);
    res.status(400).json({
      success: false,
      message: errorMessage
    });
  }
};


// Inscription pour chaque rôle
export const SignupClient = (req: Request, res: Response) => Signup(req, res, UserRole.CLIENT);
export const SignupVeterinaire = (req: Request, res: Response) => Signup(req, res, UserRole.VETERINAIRE);
export const SignupSecretaire = (req: Request, res: Response) => Signup(req, res, UserRole.SECRETAIRE);
export const SignupAdmin = (req: Request, res: Response) => Signup(req, res, UserRole.ADMIN);

// Connexion et gestion des tokens
export const Login = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;
  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
    const { accessToken, refreshToken } = await UserService.authenticateUser(username, password);
    
    console.log("🔑 Utilisateur connecté :", { username, accessToken, refreshToken });

    res.json({ message: "Connexion réussie", accessToken, refreshToken });
  } catch (error: unknown) {
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec de l'authentification" });
  }
};

// Rafraîchir le token d'accès
export const RefreshAccessToken = async (req: Request, res: Response): Promise<void> => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    res.status(400).json({ message: "Refresh token requis" });
    return;
  }

  try {
    const { accessToken } = await UserService.refreshAccessToken(refreshToken);
    res.json({ accessToken });
  } catch (error: unknown) {
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec du rafraîchissement du token" });
  }
};

// Déconnexion utilisateur
export const Logout = async (req: Request, res: Response): Promise<void> => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    res.status(400).json({ message: "Refresh token requis" });
    return;
  }

  try {
    await UserService.logoutUser(refreshToken);
    res.json({ message: "Déconnexion réussie" });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : "Échec de la déconnexion";
    res.status(400).json({ message: errorMessage });
  }
};
