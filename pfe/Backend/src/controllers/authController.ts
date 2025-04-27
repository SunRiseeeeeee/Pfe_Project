// src/controllers/authController.ts

import { Request, Response, RequestHandler, NextFunction } from "express";
import { Types } from "mongoose";
import jwt from "jsonwebtoken";
import { UserService } from "../services/userService";
import { UserRole, AuthResponse } from "../types";

// ─── Constantes de validation ────────────────────────────────────────────────
const VALID_DAYS = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"] as const;
const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;
const USERNAME_REGEX = /^[a-zA-Z0-9_]+$/;
const EMAIL_REGEX    = /^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$/;

// ─── Messages d'erreur ──────────────────────────────────────────────────────
export const ERROR_MESSAGES = {
  MISSING_FIELD:         (f: string) => `Le champ '${f}' est requis.`,
  INVALID_EMAIL:         "L'email est invalide.",
  INVALID_USERNAME:      "Le nom d'utilisateur est invalide.",
  INVALID_WORKING_HOURS: "Les heures de travail sont invalides.",
  MISSING_CREDENTIALS:   "Les informations d'identification sont manquantes.",
  INVALID_CREDENTIALS:   "Les informations d'identification sont incorrectes.",
  LOGIN_ERROR:           "Erreur de connexion.",
  MISSING_TOKEN:         "Refresh token manquant.",
  INVALID_REFRESH_TOKEN: "Refresh token invalide ou expiré.",
  TOKEN_REFRESH_FAILED:  "Échec du rafraîchissement du token.",
  LOGOUT_ERROR:          "Erreur lors de la déconnexion.",
  SIGNUP_ERROR:          "Erreur lors de l'inscription.",
  INVALID_TOKEN:         "Token invalide."
};

// ─── Helpers de validation ────────────────────────────────────────────────────
function requireString(val: unknown, name: string): string {
  if (typeof val !== "string" || !val.trim()) {
    throw new Error(ERROR_MESSAGES.MISSING_FIELD(name));
  }
  return val.trim();
}
function validateEmail(email: string): void {
  if (!EMAIL_REGEX.test(email)) {
    throw new Error(ERROR_MESSAGES.INVALID_EMAIL);
  }
}
function validateUsername(username: string): void {
  if (!USERNAME_REGEX.test(username)) {
    throw new Error(ERROR_MESSAGES.INVALID_USERNAME);
  }
}
function validateWorkingHoursFormat(hours: unknown): Array<{day:string;start:string;end:string}> {
  if (!Array.isArray(hours)) {
    throw new Error(ERROR_MESSAGES.INVALID_WORKING_HOURS);
  }
  (hours as any[]).forEach(slot => {
    const { day, start, end } = slot || {};
    if (!day || !start || !end) {
      throw new Error("Chaque plage horaire doit contenir day, start et end");
    }
    if (!VALID_DAYS.includes(day)) {
      throw new Error(`Jour invalide : ${day}`);
    }
    if (!TIME_REGEX.test(start) || !TIME_REGEX.test(end)) {
      throw new Error("Le format des heures doit être HH:MM");
    }
  });
  return hours as any;
}
const sanitize = (v?: string): string|undefined => v?.trim();

// ─── Handler d’inscription générique ─────────────────────────────────────────
async function handleSignup(
  req: Request,
  res: Response<AuthResponse>,
  role: UserRole
): Promise<void> {
  try {
    // — Champs obligatoires —
    const firstName   = requireString(req.body.firstName,   "firstName");
    const lastName    = requireString(req.body.lastName,    "lastName");
    const usernameRaw = requireString(req.body.username,    "username").toLowerCase();
    const emailRaw    = requireString(req.body.email,       "email").toLowerCase();
    const password    = requireString(req.body.password,    "password");
    const phoneNumber = requireString(req.body.phoneNumber, "phoneNumber");

    validateUsername(usernameRaw);
    validateEmail(emailRaw);

    // — Extras facultatifs —
    const extra: any = {
      profilePicture: sanitize(req.body.profilePicture),
      mapsLocation:   sanitize(req.body.mapsLocation),
      description:    sanitize(req.body.description),
      details:        {},
      reviews:        []
    };

    if (role === UserRole.VETERINAIRE) {
      if (Array.isArray(req.body.services)) {
        extra.details.services = req.body.services;
      }
      if (Array.isArray(req.body.workingHours)) {
        extra.details.workingHours = validateWorkingHoursFormat(req.body.workingHours);
      }
      extra.rating = 0;
    }

    // — Création en base —
    const createdUser = await UserService.createUser(
      { firstName, lastName, username: usernameRaw, email: emailRaw, password, phoneNumber, role },
      extra
    );

    const userId = (createdUser as any).id;
    if (!userId) {
      throw new Error("Impossible de récupérer l'ID de l'utilisateur créé");
    }

    res.status(201).json({
      success: true,
      message: `${role} inscrit avec succès`,
      userId
    });

  } catch (err: any) {
    console.error("[signup] Error:", err);
    res.status(400).json({
      success: false,
      message: err.message || ERROR_MESSAGES.SIGNUP_ERROR,
      error: "SIGNUP_ERROR"
    });
  }
}

// ─── Routes d’inscription ────────────────────────────────────────────────────
export const signupClient:      RequestHandler = (req, res, next) => handleSignup(req, res, UserRole.CLIENT).catch(next);
export const signupVeterinaire: RequestHandler = (req, res, next) => handleSignup(req, res, UserRole.VETERINAIRE).catch(next);
export const signupSecretaire:  RequestHandler = (req, res, next) => handleSignup(req, res, UserRole.SECRETAIRE).catch(next);
export const signupAdmin:       RequestHandler = (req, res, next) => handleSignup(req, res, UserRole.ADMIN).catch(next);

// ─── Handler de connexion ─────────────────────────────────────────────────────
export const login: RequestHandler = async (req, res, next) => {
  try {
    const { username, password } = req.body as { username?: string; password?: string };
    if (!username || !password) {
      res.status(400).json({
        success: false,
        message: ERROR_MESSAGES.MISSING_CREDENTIALS,
        error:   "MISSING_CREDENTIALS"
      });
      return;
    }
    const auth = await UserService.authenticateUser({
      username: username.trim(),
      password: password.trim()
    });
    res.status(200).json({
      success: true,
      message: "Connexion réussie",
      tokens: { accessToken: auth.accessToken, refreshToken: auth.refreshToken },
      user: auth.user
    });
  } catch (err: any) {
    next(err);
  }
};

// ─── Handler de rafraîchissement de token ────────────────────────────────────

export const refreshAccessToken: RequestHandler = async (req, res) => {
  const { refreshToken } = req.body as { refreshToken?: string };

  if (!refreshToken?.trim()) {
    res.status(400).json({
      success: false,
      message: ERROR_MESSAGES.MISSING_TOKEN,
      error:   "MISSING_TOKEN"
    });
    return;
  }

  try {
    const { accessToken, refreshToken: newRefreshToken } =
      await UserService.refreshAccessToken(refreshToken.trim());

    res.status(200).json({
      success: true,
      message: "Token rafraîchi avec succès",
      tokens: { accessToken, refreshToken: newRefreshToken }
    });
  } catch (err: any) {
    console.error("[refreshAccessToken] Error:", err);

    if (err.message === "Refresh token expired") {
      res.status(401).json({
        success: false,
        message: err.message,
        error:   "TOKEN_EXPIRED"
      });
    } else if (err.message === ERROR_MESSAGES.INVALID_REFRESH_TOKEN) {
      res.status(401).json({
        success: false,
        message: err.message,
        error:   "INVALID_REFRESH_TOKEN"
      });
    } else {
      res.status(500).json({
        success: false,
        message: ERROR_MESSAGES.TOKEN_REFRESH_FAILED,
        error:   "TOKEN_REFRESH_FAILED"
      });
    }
  }
};





// ─── Handler de déconnexion ───────────────────────────────────────────────────
export const logout: RequestHandler = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({ success: false, message: "Token manquant ou invalide" });
      return;
    }
    const token = authHeader.slice(7);
    let payload: any;
    try {
      payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET!);
    } catch {
      res.status(401).json({ success: false, message: ERROR_MESSAGES.INVALID_TOKEN, error: "INVALID_TOKEN" });
      return;
    }
    const userId = payload.id;
    if (!Types.ObjectId.isValid(userId)) {
      res.status(400).json({ success: false, message: "userId invalide" });
      return;
    }
    await UserService.logout(userId);
    res.status(200).json({ success: true, message: "Déconnexion réussie" });
  } catch (err: any) {
    next(err);
  }
};

// ─── Middleware de gestion des erreurs ────────────────────────────────────────
export const errorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  console.error("[errorHandler]", err);
  if (err.message === ERROR_MESSAGES.INVALID_CREDENTIALS) {
    res.status(401).json({ success: false, message: err.message, error: "INVALID_CREDENTIALS" });
    return;
  }
  if (err.message === ERROR_MESSAGES.INVALID_REFRESH_TOKEN) {
    res.status(401).json({ success: false, message: err.message, error: "INVALID_REFRESH_TOKEN" });
    return;
  }
  res.status(500).json({ success: false, message: err.message || "Une erreur est survenue", error: "SERVER_ERROR" });
};
