import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import express from "express";

// Interface pour étendre Request et inclure l'utilisateur décodé
export interface AuthRequest extends Request {
  user?: any; // Type défini selon la structure de ton utilisateur décodé
}

export const authenticateToken: express.RequestHandler = (
  req: AuthRequest, 
  res: Response, 
  next: NextFunction
) => {
  // Récupération du token depuis l'en-tête Authorization
  const token = req.header("Authorization")?.replace("Bearer ", "");

  // Vérification de la présence du token
  if (!token) {
    res.status(401).json({ message: "Accès interdit, token manquant" });
    return; // Ici on termine la requête sans appeler `next()`
  }

  try {
    // Décodage du token et ajout de l'utilisateur dans la requête
    const decoded = jwt.verify(token, process.env.JWT_SECRET!);
    req.user = decoded; // Stockage de l'utilisateur dans `req.user`
    next(); // Appel du prochain middleware ou contrôleur
  } catch (error) {
    res.status(403).json({ message: "Accès interdit, token invalide" });
    return; // Terminer la requête sans appeler `next()`
  }
};
