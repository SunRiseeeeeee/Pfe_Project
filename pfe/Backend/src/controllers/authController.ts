import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";

// Inscription d'un utilisateur (générique pour tous les rôles)
// Inscription d'un utilisateur
const Signup = async (req: Request, res: Response, role: UserRole): Promise<void> => {
  const { 
    firstName, 
    lastName, 
    username, 
    email, 
    password, 
    phoneNumber, 
    profilePicture = null, 
    location = null, 
    description = null,
    specialty = null, 
    workingHours = null 
  } = req.body;

  try {
    // Validation des données requises
    if (!firstName || !lastName || !username || !email || !password || !phoneNumber) {
      throw new Error('Tous les champs obligatoires doivent être remplis');
    }

    const extraDetails: Record<string, any> = { 
      profilePicture,
      location,
      description,
      details: {},
      reviews: []
    };

    // Configuration spécifique au rôle
    if (role === UserRole.VETERINAIRE) {
      extraDetails.details = { specialty, workingHours };
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

    // Créer l'utilisateur
    const user = await UserService.createUser(userData, extraDetails);
    
    res.status(201).json({ 
      success: true,
      message: `${role} inscrit avec succès`,
      userId: user._id // Retourne l'ID du nouvel utilisateur
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
