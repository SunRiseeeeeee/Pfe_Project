// src/controllers/authController.ts

import { Request, Response, RequestHandler } from "express";
import { Types } from "mongoose";

import { UserService } from "../services/userService";
import { UserRole, AuthResponse } from "../types";

// ── Validation constants ──────────────────────────────────────────────────────

const VALID_DAYS = [
  "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
] as const;

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;
const USERNAME_REGEX = /^[a-zA-Z0-9_]+$/;
const EMAIL_REGEX    = /^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$/;

const ERROR_MESSAGES = {
  MISSING_FIELD:         (f: string) => `Le champ ${f} est obligatoire`,
  INVALID_EMAIL:         "Adresse email invalide",
  INVALID_USERNAME:      "Nom d'utilisateur invalide (lettres, chiffres, _)",
  INVALID_SERVICES:      "Les services doivent être un tableau non vide",
  INVALID_WORKING_HOURS: "Les horaires doivent être un tableau non vide",
  MISSING_CREDENTIALS:   "Nom d'utilisateur et mot de passe requis",
  INVALID_CREDENTIALS:   "Invalid credentials",
  MISSING_TOKEN:         "Refresh token requis",
  SIGNUP_ERROR:          "Erreur lors de l'inscription",
  LOGIN_ERROR:           "Erreur lors de la connexion",
  TOKEN_REFRESH_FAILED:  "Échec du rafraîchissement du token",
  LOGOUT_ERROR:          "Échec de la déconnexion"
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function validateRequired(val: unknown, name: string): string {
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

function validateUsername(u: string): void {
  if (!USERNAME_REGEX.test(u)) {
    throw new Error(ERROR_MESSAGES.INVALID_USERNAME);
  }
}

function validateWorkingHours(slots: any[]): void {
  if (!Array.isArray(slots) || slots.length === 0) {
    throw new Error(ERROR_MESSAGES.INVALID_WORKING_HOURS);
  }
  for (const { day, start, end } of slots) {
    if (!day || !start || !end) {
      throw new Error("Chaque plage horaire nécessite day, start et end");
    }
    if (!(VALID_DAYS as readonly string[]).includes(day)) {
      throw new Error(`Jour invalide: ${day}`);
    }
    if (!TIME_REGEX.test(start) || !TIME_REGEX.test(end)) {
      throw new Error("Format d'heure invalide (HH:MM)");
    }
  }
}

function sanitize(str?: string): string | undefined {
  return str?.trim();
}

// ── Signup handler ────────────────────────────────────────────────────────────

async function handleSignup(
  req: Request,
  res: Response<AuthResponse>,
  role: UserRole
): Promise<void> {
  try {
    const {
      firstName: fn,
      lastName: ln,
      username,
      email,
      password,
      phoneNumber,
      services,
      workingHours,
      profilePicture,
      mapsLocation,
      description
    } = req.body;

    const firstName = validateRequired(fn, "firstName");
    const lastName  = validateRequired(ln, "lastName");
    const usr       = validateRequired(username, "username");
    const mail      = validateRequired(email, "email");
    const pwd       = validateRequired(password, "password");
    const phone     = validateRequired(phoneNumber, "phoneNumber");

    validateUsername(usr);
    validateEmail(mail);

    const extra: any = {
      profilePicture: sanitize(profilePicture),
      mapsLocation:   sanitize(mapsLocation),
      description:    sanitize(description),
      details:        {},
      reviews:        []
    };

    if (role === UserRole.VETERINAIRE) {
      validateRequired(services, "services");
      validateRequired(workingHours, "workingHours");
      validateWorkingHours(workingHours);
      extra.details = { services, workingHours };
      extra.rating  = 0;
    }

    const user = await UserService.createUser(
      {
        firstName,
        lastName,
        username:    usr.toLowerCase(),
        email:       mail.toLowerCase(),
        password:    pwd,
        phoneNumber: phone,
        role
      },
      extra
    );

    res.status(201).json({
      success: true,
      message: `${role} inscrit avec succès`,
      userId:  user._id.toString()
    });
    return;
  } catch (err: any) {
    console.error("Signup error:", err);
    res.status(400).json({
      success: false,
      message: err.message || ERROR_MESSAGES.SIGNUP_ERROR,
      error:   "SIGNUP_ERROR"
    });
    return;
  }
}

export const signupClient:      RequestHandler = (req, res) => handleSignup(req, res, UserRole.CLIENT);
export const signupVeterinaire: RequestHandler = (req, res) => handleSignup(req, res, UserRole.VETERINAIRE);
export const signupSecretaire:  RequestHandler = (req, res) => handleSignup(req, res, UserRole.SECRETAIRE);
export const signupAdmin:       RequestHandler = (req, res) => handleSignup(req, res, UserRole.ADMIN);

// ── Login handler ────────────────────────────────────────────────────────────

export const login: RequestHandler = async (req, res) => {
  console.log("[login] body:", req.body);
  try {
    const { username, password } = req.body as { username?: string; password?: string };
    if (!username || !password) {
      res.status(400).json({ success: false, message: ERROR_MESSAGES.MISSING_CREDENTIALS });
      return;
    }

    const auth = await UserService.authenticateUser({
      username: username.trim(),
      password: password.trim()
    });

    res.status(200).json({
      success: true,
      message: "Connexion réussie",
      tokens: {
        accessToken:  auth.accessToken,
        refreshToken: auth.refreshToken
      },
      user: auth.user
    });
    return;
  } catch (err: any) {
    console.error("[login] Error:", err.stack);
    const isBad = err.message === ERROR_MESSAGES.INVALID_CREDENTIALS;
    res.status(isBad ? 401 : 500).json({
      success: false,
      message: err.message || ERROR_MESSAGES.LOGIN_ERROR,
      error:   isBad ? "INVALID_CREDENTIALS" : "LOGIN_ERROR"
    });
    return;
  }
};

// ── Refresh token handler ────────────────────────────────────────────────────

export const refreshAccessToken: RequestHandler = async (req, res) => {
  try {
    const { refreshToken } = req.body as { refreshToken?: string };
    if (!refreshToken) {
      res.status(400).json({ success: false, message: ERROR_MESSAGES.MISSING_TOKEN });
      return;
    }

    const { accessToken } = await UserService.refreshAccessToken(refreshToken.trim());
    res.json({
      success: true,
      message: "Token rafraîchi avec succès",
      tokens: { accessToken, refreshToken }
    });
    return;
  } catch (err: any) {
    console.error("[refresh] Error:", err.stack);
    res.status(401).json({
      success: false,
      message: err.message || ERROR_MESSAGES.TOKEN_REFRESH_FAILED,
      error:   "TOKEN_REFRESH_FAILED"
    });
    return;
  }
};

// ── Logout handler ───────────────────────────────────────────────────────────

export const logout: RequestHandler = async (req, res) => {
  try {
    const { userId } = req.body as { userId?: string };
    if (!userId || !Types.ObjectId.isValid(userId)) {
      res.status(400).json({ success: false, message: "userId invalide" });
      return;
    }

    await UserService.logout(userId);
    res.json({ success: true, message: "Déconnexion réussie" });
    return;
  } catch (err: any) {
    console.error("[logout] Error:", err.stack);
    res.status(500).json({
      success: false,
      message: err.message || ERROR_MESSAGES.LOGOUT_ERROR,
      error:   "LOGOUT_ERROR"
    });
    return;
  }
};
