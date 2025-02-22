import { Request, Response } from "express";
import { UserService } from "../services/userService";
import { UserRole } from "../models/User";

// Signup pour le client
export const SignupClient = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;

  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
    const user = await UserService.createUser(username, password, UserRole.CLIENT);
    res.status(201).json({ message: "Client inscrit avec succès", user });
  } catch (error: unknown) {
    res.status(400).json({ message: error instanceof Error ? error.message : "Erreur d'inscription" });
  }
};

// Signup pour la secrétaire
export const SignupSecretaire = async (req: Request, res: Response): Promise<void> => {
  const { username, password } = req.body;

  if (!username || !password) {
    res.status(400).json({ message: "Nom d'utilisateur et mot de passe requis" });
    return;
  }

  try {
    const user = await UserService.createUser(username, password, UserRole.SECRETAIRE);
    res.status(201).json({ message: "Secrétaire inscrite avec succès", user });
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