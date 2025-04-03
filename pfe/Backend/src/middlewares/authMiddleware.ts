import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import express from "express";

export interface AuthRequest extends Request {
  user?: any;
}

export const authenticateToken: express.RequestHandler = (
  req: AuthRequest, 
  res: Response, 
  next: NextFunction
) => {
  const token = req.header("Authorization")?.replace("Bearer ", "");

  if (!token) {
    res.status(401).json({ message: "Accès interdit, token manquant" });
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(403).json({ message: "Accès interdit, token invalide" });
    return;
  }
};