import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";

// Signup pour le client
export const SignupClient = async (req: Request, res: Response): Promise<void> => {
  const { firstName, lastName, username, email, password, phoneNumber, profilePicture, location } = req.body;
  try {
    const user = await UserService.createUser(firstName, lastName, username, email, password, phoneNumber, UserRole.CLIENT, { profilePicture, location });
    res.status(201).json({ message: "Client inscrit avec succès", user });
  } catch (error: unknown) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur d'inscription" });
  }
};

export const SignupVeterinaire = async (req: Request, res: Response): Promise<void> => {
  const { firstName, lastName, username, email, password, phoneNumber, profilePicture, location, specialty, workingHours } = req.body;
  
  // On vérifie si les informations sont bien présentes
  if (!firstName || !lastName || !username || !email || !password || !phoneNumber || !specialty || !workingHours) {
    res.status(400).json({ message: "Tous les champs sont requis" });
    return;
  }

  try {
    // Création de l'utilisateur vétérinaire avec les informations spécifiques au rôle
    const user = await UserService.createUser(
      username, 
      email, 
      password, 
      lastName, 
      firstName, 
      UserRole.VETERINAIRE, 
      phoneNumber, 
      {
        profilePicture, 
        location,
        details: { specialty, workingHours },
        reviews: [],  // Initialisation de reviews avec un tableau vide
      }
    );

    res.status(201).json({ message: "Vétérinaire inscrit avec succès", user });
  } catch (error: unknown) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur d'inscription" });
  }
};


// Signup pour la secrétaire
export const SignupSecretaire = async (req: Request, res: Response): Promise<void> => {
  const { firstName, lastName, username, email, password, phoneNumber, profilePicture, workingHours } = req.body;
  try {
    const user = await UserService.createUser(firstName, lastName, username, email, password, phoneNumber, UserRole.SECRETAIRE, {
      profilePicture,
      details: { workingHours },
    });

    res.status(201).json({ message: "Secrétaire inscrite avec succès", user });
  } catch (error: unknown) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur d'inscription" });
  }
};

// Signup pour l'admin
export const SignupAdmin = async (req: Request, res: Response): Promise<void> => {
  const { firstName, lastName, username, email, password, phoneNumber } = req.body;
  try {
    const user = await UserService.createUser(firstName, lastName, username, email, password, phoneNumber, UserRole.ADMIN);
    res.status(201).json({ message: "Admin inscrit avec succès", user });
  } catch (error: unknown) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur d'inscription" });
  }
};

// Login pour le client
export const LoginClient = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;

  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
    const token = await UserService.authenticateUser(username, password);
    res.json({ message: "Connexion client réussie", token });
  } catch (error: unknown) {
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec de l'authentification du client" });
  }
};

// Login pour le vétérinaire
export const LoginVeterinaire = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;

  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
    const token = await UserService.authenticateUser(username, password);
    res.json({ message: "Connexion vétérinaire réussie", token });
  } catch (error: unknown) {
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec de l'authentification du vétérinaire" });
  }
};

// Login pour la secrétaire
export const LoginSecretaire = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;

  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
    const token = await UserService.authenticateUser(username, password);
    res.json({ message: "Connexion secrétaire réussie", token });
  } catch (error: unknown) {
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec de l'authentification de la secrétaire" });
  }
};

// Login pour l'admin
export const LoginAdmin = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;

  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
    const token = await UserService.authenticateUser(username, password);
    res.json({ message: "Connexion admin réussie", token });
  } catch (error: unknown) {
    res.status(401).json({ message: error instanceof Error ? error.message : "Échec de l'authentification de l'admin" });
  }
};
