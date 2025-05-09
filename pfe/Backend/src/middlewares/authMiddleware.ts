import { Request, Response, NextFunction, RequestHandler } from "express";
// Ajouter en haut du fichier
import dotenv from 'dotenv';
dotenv.config();

import jwt from "jsonwebtoken";
import { UserRole } from "../models/User";

// 1. Interface pour l'adresse
export interface UserAddress {
  street?: string;
  city?: string;
  state?: string;
  country?: string;
  postalCode?: string;
}

// 2. Interface pour le payload utilisateur
export interface UserTokenPayload {
  id: string;
  role: UserRole;
  firstName: string;
  lastName: string;
  username: string;
  phoneNumber: string;
  profilePicture?: string;
  address?: UserAddress;
  veterinaireId?:string;
}

// 3. Interface pour le payload JWT
export interface JwtPayload extends UserTokenPayload {
  iat?: number;
  exp?: number;
}

// 4. Extension de l'interface Request d'Express
declare global {
  namespace Express {
    interface Request {
      user?: UserTokenPayload;
    }
  }
}

// 5. Constantes pour la gestion des erreurs
const ERROR_CODES = {
  MISSING_TOKEN: "MISSING_TOKEN",
  SERVER_ERROR: "SERVER_ERROR",
  INVALID_TOKEN_FORMAT: "INVALID_TOKEN_FORMAT",
  TOKEN_EXPIRED: "TOKEN_EXPIRED",
  INVALID_TOKEN: "INVALID_TOKEN",
  AUTH_ERROR: "AUTH_ERROR"
} as const;

const ERROR_MESSAGES = {
  [ERROR_CODES.MISSING_TOKEN]: "Authentification requise - Token manquant",
  [ERROR_CODES.SERVER_ERROR]: "Erreur de configuration serveur",
  [ERROR_CODES.INVALID_TOKEN_FORMAT]: "Token malformé ou incomplet",
  [ERROR_CODES.TOKEN_EXPIRED]: "Session expirée - Token périmé",
  [ERROR_CODES.INVALID_TOKEN]: "Token invalide",
  [ERROR_CODES.AUTH_ERROR]: "Erreur d'authentification"
};

// 6. Middleware corrigé avec typage strict
export const authenticateToken: RequestHandler = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader?.split(' ')[1];

    if (!token) {
      res.status(401).json({
        success: false,
        message: ERROR_MESSAGES.MISSING_TOKEN,
        code: ERROR_CODES.MISSING_TOKEN
      });
      return;
    }

    if (!process.env.JWT_SECRET) {
      console.error('JWT_SECRET non configuré');
      res.status(500).json({
        success: false,
        message: ERROR_MESSAGES.SERVER_ERROR,
        code: ERROR_CODES.SERVER_ERROR
      });
      return;
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET) as JwtPayload;

    // Validation des champs obligatoires
    const requiredFields = ['id', 'role', 'firstName', 'lastName', 'username', 'phoneNumber'];
    const missingFields = requiredFields.filter(field => !decoded[field as keyof JwtPayload]);

    if (missingFields.length > 0) {
      res.status(403).json({
        success: false,
        message: `Token incomplet. Champs manquants: ${missingFields.join(', ')}`,
        code: ERROR_CODES.INVALID_TOKEN_FORMAT
      });
      return;
    }

    // Assignation des données utilisateur
    req.user = {
      id: decoded.id,
      role: decoded.role,
      firstName: decoded.firstName,
      lastName: decoded.lastName,
      username: decoded.username,
      phoneNumber: decoded.phoneNumber,
      profilePicture: decoded.profilePicture,
      address: decoded.address,
      veterinaireId:decoded.veterinaireId,
    };

    next();
  } catch (error) {
    console.error('Erreur d\'authentification:', error);

    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({
        success: false,
        message: ERROR_MESSAGES.TOKEN_EXPIRED,
        code: ERROR_CODES.TOKEN_EXPIRED
      });
      return;
    }

    if (error instanceof jwt.JsonWebTokenError) {
      res.status(403).json({
        success: false,
        message: ERROR_MESSAGES.INVALID_TOKEN,
        code: ERROR_CODES.INVALID_TOKEN
      });
      return;
    }

    res.status(500).json({
      success: false,
      message: ERROR_MESSAGES.AUTH_ERROR,
      code: ERROR_CODES.AUTH_ERROR
    });
  }
};