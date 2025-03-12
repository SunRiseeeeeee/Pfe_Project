import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";

// Inscription d'un utilisateur
const Signup = async (req: Request, res: Response, role: UserRole): Promise<void> => {
  const { firstName, lastName, username, email, password, phoneNumber, profilePicture, location, specialty, workingHours } = req.body;
  try {
    const extraDetails: any = { profilePicture, location };
    if (role === UserRole.VETERINAIRE) {
      extraDetails.details = { specialty, workingHours };
      extraDetails.reviews = [];
    } else if (role === UserRole.SECRETAIRE) {
      extraDetails.details = { workingHours };
    }
    await UserService.createUser(firstName, lastName, username, email, password, phoneNumber, role, extraDetails);
    res.status(201).json({ message: `${role} inscrit avec succès` });
  } catch (error: unknown) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur d'inscription" });
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

export const Logout = async (req: Request, res: Response): Promise<void> => {
  const { refreshToken } = req.body;

  // Vérifier si le refreshToken est fourni
  if (!refreshToken) {
    res.status(400).json({ message: "Refresh token requis" });
    return;
  }

  try {
    // Appeler la méthode logoutUser de UserService
    await UserService.logoutUser(refreshToken);
    res.json({ message: "Déconnexion réussie" });
  } catch (error: unknown) {
    // Gérer les erreurs de manière propre
    const errorMessage = error instanceof Error ? error.message : "Échec de la déconnexion";
    res.status(400).json({ message: errorMessage });
  }
};

