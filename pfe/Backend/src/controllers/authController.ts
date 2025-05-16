import { Request, Response, NextFunction, RequestHandler, ErrorRequestHandler } from "express";
import mongoose, { Types } from "mongoose";
import jwt from "jsonwebtoken";
import { AuthService, UserService } from "../services/userService";
import { UserRole } from "../types";
import User, { IUser, IUserDetails } from "../models/User";
import bcrypt from "bcryptjs";
import { upload } from "../services/animalMulterConfig";
import nodemailer from "nodemailer"; 
import crypto from 'crypto';  // Utilise cette importation pour accéder à 'randomBytes'
import { userUpload } from '../services/userMulterConfig';


//#region Interfaces et Types
interface WorkingHours {
  day: string;
  start: string;
  end: string;
  pauseStart?: string;
  pauseEnd?: string;
}

interface Address {
  street?: string;
  city?: string;
  state?: string;
  country?: string;
  postalCode?: string;
}

interface UserDetails {
  services?: string[];
  workingHours?: WorkingHours[];
  specialization?: string;
  experienceYears?: number;
}

interface SignupRequest {
  firstName: string;
  lastName: string;
  username: string;
  email: string;
  password: string;
  phoneNumber: string;
  profilePicture?: string;
  mapsLocation?: string;
  description?: string;
  address?: Address;
  details?: {
    services?: string[];
    workingHours?: WorkingHours[];
    specialization?: string;
    experienceYears?: number;
  };
}

interface LoginRequest {
  username: string;
  password: string;
}

interface RefreshTokenRequest {
  refreshToken: string;
}

interface SafeUserInfo {
  id: string;
  role: UserRole;
  firstName: string;
  lastName: string;
  email: string;
  username: string;
  phoneNumber: string;
  profilePicture?: string;
  address?: Address;
  details?: UserDetails;
  mapsLocation?: string;
  description?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  user: SafeUserInfo;
}

interface AuthResponse {
  success: boolean;
  message: string;
  userId?: string;
  tokens?: {
    accessToken: string;
    refreshToken: string;
  };
  user?: SafeUserInfo;
  error?: string;
  debug?: {
    stack?: string;
    [key: string]: unknown;
  };
}

type ErrorMessage = string | ((context?: string) => string);
type ErrorMessages = Record<string, ErrorMessage>;

interface ErrorResponse {
  status: number;
  code: string;
  message: string;
}
//#endregion

//#region Constants
const VALID_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] as const;
const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;
const USERNAME_REGEX = /^[a-zA-Z0-9_]+$/;
const EMAIL_REGEX = /^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$/;
const PHONE_REGEX = /^[0-9]{8,15}$/;

const ERROR_MESSAGES: ErrorMessages = {
  MISSING_FIELD: (field?: string) => `Le champ ${field ? `'${field}'` : ''} est requis.`,
  INVALID_EMAIL: "L'email est invalide.",
  INVALID_USERNAME: "Le nom d'utilisateur est invalide (caractères alphanumériques et _ uniquement).",
  INVALID_PHONE: "Le numéro de téléphone doit contenir 8 à 15 chiffres.",
  INVALID_WORKING_HOURS: "Les heures de travail sont invalides.",
  MISSING_CREDENTIALS: "Identifiants manquants.",
  INVALID_CREDENTIALS: "Identifiants incorrects.",
  MISSING_TOKEN: "Token manquant.",
  INVALID_TOKEN: "Token invalide.",
  SERVER_ERROR: "Erreur serveur.",
  ACCOUNT_LOCKED: (minutes?: string) => `Compte bloqué. Réessayez dans ${minutes || 'quelques'} minutes.`,
  VALIDATION_ERROR: "Erreur de validation",
  DUPLICATE_USER: "Un utilisateur avec ces informations existe déjà",
  ACCOUNT_INACTIVE: "Le compte est désactivé"
};

const getErrorMessage = (code: string, context?: string): string => {
  const message = ERROR_MESSAGES[code];
  return typeof message === 'function' ? message(context) : message || "Erreur inconnue";
};
//#endregion

//#region Helper Functions
const validateRequiredString = (value: unknown, fieldName: string): string => {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(getErrorMessage("MISSING_FIELD", fieldName));
  }
  return value.trim();
};

const validateEmailFormat = (email: string): void => {
  if (!EMAIL_REGEX.test(email)) {
    throw new Error(getErrorMessage("INVALID_EMAIL"));
  }
};

const validateUsernameFormat = (username: string): void => {
  if (!USERNAME_REGEX.test(username)) {
    throw new Error(getErrorMessage("INVALID_USERNAME"));
  }
};

const validatePhoneFormat = (phone: string): void => {
  if (!PHONE_REGEX.test(phone)) {
    throw new Error(getErrorMessage("INVALID_PHONE"));
  }
};

const sanitizeOptionalString = (value?: unknown): string | undefined => {
  if (value === null || value === undefined) return undefined;
  return typeof value === 'string' ? value.trim() : String(value).trim();
};

const validateWorkingHours = (hours: unknown): WorkingHours[] => {
  if (!Array.isArray(hours)) {
    throw new Error(getErrorMessage("INVALID_WORKING_HOURS"));
  }

  return hours.map((slot, index) => {
    const { day, start, pauseStart, pauseEnd, end } = slot || {};
    
    if (!day || !start || !end) {
      throw new Error(`Plage horaire ${index + 1} incomplète`);
    }

    if (!VALID_DAYS.includes(day as typeof VALID_DAYS[number])) {
      throw new Error(`Jour invalide: ${day}`);
    }

    [start, end, pauseStart, pauseEnd].forEach((time, i) => {
      if (time && !TIME_REGEX.test(time)) {
        throw new Error(`Format de temps invalide pour ${['start', 'end', 'pauseStart', 'pauseEnd'][i]}`);
      }
    });

    return { 
      day, 
      start, 
      end, 
      ...(pauseStart && { pauseStart }), 
      ...(pauseEnd && { pauseEnd }) 
    };
  });
};

const buildExtraDetails = (role: UserRole, body: SignupRequest): Partial<IUser> => {
  const details: Partial<IUser> = {
    profilePicture: sanitizeOptionalString(body.profilePicture),
    mapsLocation: sanitizeOptionalString(body.mapsLocation),
    description: sanitizeOptionalString(body.description),
    address: body.address ? {
      street: sanitizeOptionalString(body.address.street),
      city: sanitizeOptionalString(body.address.city),
      state: sanitizeOptionalString(body.address.state),
      country: sanitizeOptionalString(body.address.country),
      postalCode: sanitizeOptionalString(body.address.postalCode)
    } : undefined,
    details: {
      services: Array.isArray(body.details?.services) ? body.details.services : [],
      workingHours: body.details?.workingHours ? validateWorkingHours(body.details.workingHours) : [],
      specialization: sanitizeOptionalString(body.details?.specialization),
      experienceYears: Number(body.details?.experienceYears) || 0
    }
  };


  return details;
};

const handleControllerError = (error: unknown): ErrorResponse => {
  console.error('Controller error:', error);

  if (error instanceof mongoose.Error.ValidationError) {
    return {
      status: 400,
      code: "VALIDATION_ERROR",
      message: error.message
    };
  }

  if (error instanceof Error) {
    if (error.message.includes('DUPLICATE_USER') || (error as any).code === 11000) {
      return {
        status: 409,
        code: "DUPLICATE_USER",
        message: getErrorMessage("DUPLICATE_USER")
      };
    }
    if (error.message.includes('VALIDATION_ERROR')) {
      return {
        status: 400,
        code: "VALIDATION_ERROR",
        message: error.message.replace('VALIDATION_ERROR: ', '')
      };
    }
    if (error.message.includes('Account locked')) {
      const minutes = error.message.match(/\d+/)?.[0];
      return {
        status: 403,
        code: "ACCOUNT_LOCKED",
        message: getErrorMessage("ACCOUNT_LOCKED", minutes)
      };
    }
    if (error.message.includes('ACCOUNT_INACTIVE')) {
      return {
        status: 403,
        code: "ACCOUNT_INACTIVE",
        message: getErrorMessage("ACCOUNT_INACTIVE")
      };
    }
  }

  return {
    status: 500,
    code: "SERVER_ERROR",
    message: getErrorMessage("SERVER_ERROR")
  };
};
//#endregion

//#region Controller Handlers

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// Fonction de réinitialisation du mot de passe
export const resetPassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, code, newPassword } = req.body;
    if (!email || !code || !newPassword) {
      res.status(400).json({ message: "All fields are required" });
      return;
    }

    // 🔑 On “ré-active” les champs cachés
    const user = await User
      .findOne({ email: email.toLowerCase() })
      .select("+resetPasswordCode +resetPasswordExpires");

    if (!user) {
      res.status(404).json({ message: "User not found" });
      return;
    }

    console.log("Code dans la base de données:", user.resetPasswordCode);
    console.log("Date d'expiration dans la base :", user.resetPasswordExpires);

    if (
      user.resetPasswordCode !== code ||
      !user.resetPasswordExpires ||
      user.resetPasswordExpires.getTime() < Date.now()
    ) {
      res.status(400).json({ message: "Invalid or expired verification code" });
      return;
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    user.resetPasswordCode = undefined;
    user.resetPasswordExpires = undefined;

    await user.save();

    res.status(200).json({ message: "Password has been reset successfully" });
    return;
  } catch (error) {
    console.error("Error during password reset:", error);
    res.status(500).json({ message: "Internal server error" });
    return;
  }
};

// Fonction de demande de réinitialisation de mot de passe (Oublié)
export const forgetPassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email } = req.body;

    if (!email) {
      res.status(400).json({ message: "Email is required" });
      return;
    }

    const user = await User.findOne({ email });

    if (!user) {
      res.status(404).json({ message: "User not found" });
      return;
    }

    // 🔍 Génération du code et de l'expiration
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // 🔄 Mise à jour de l'utilisateur avec le code et la date d'expiration
    user.resetPasswordCode = code;
    user.resetPasswordExpires = expires;

    // 🔍 Logs pour vérifier avant sauvegarde
    console.log("Avant sauvegarde - Code :", user.resetPasswordCode);
    console.log("Avant sauvegarde - Expiration :", user.resetPasswordExpires);

    // ✅ Sauvegarde dans la base de données
    await user.save();

    // 🔍 Vérification après sauvegarde
    const updatedUser = await User.findOne({ email });  // Récupération de l'utilisateur après la sauvegarde
    console.log("Après sauvegarde - Code :", updatedUser?.resetPasswordCode);
    console.log("Après sauvegarde - Expiration :", updatedUser?.resetPasswordExpires);

    // 📧 Envoi de l'email
    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: email,
      subject: "Reset your password",
      text: `Your verification code is ${code}. It will expire in 10 minutes.`,
    });

    res.status(200).json({ message: "Verification code sent successfully" });

  } catch (error) {
    console.error("Error during password reset request:", error);
    res.status(500).json({ message: "Something went wrong" });
  }
};

export const signupHandler = (role: UserRole): RequestHandler => {
  return async (req: Request, res: Response, next: NextFunction) => {
    userUpload(req, res, async (err) => {
      if (err) {
        return res.status(400).json({
          success: false,
          message: "Erreur lors de l'upload de l'image",
          error: err.message,
        });
      }

      try {
        const {
          firstName,
          lastName,
          username,
          email,
          password,
          phoneNumber,
          mapsLocation,
          description,
          address,
          details,
        } = req.body;

        // Récupération du veterinaireId depuis l'URL si le rôle est SECRETAIRE
        const veterinaireId = role === UserRole.SECRETAIRE ? req.params.veterinaireId : undefined;

        // Vérification des champs obligatoires
        if (!username || !firstName || !lastName || !password || !email || !phoneNumber) {
          return res.status(400).json({
            success: false,
            message: 'Tous les champs obligatoires doivent être fournis',
            requiredFields: {
              username: 'string',
              firstName: 'string',
              lastName: 'string',
              password: 'string (min 8 caractères)',
              email: 'string (format email)',
              phoneNumber: 'string (8-15 chiffres)'
            }
          });
        }

        // Validation spécifique pour les secrétaires
        if (role === UserRole.SECRETAIRE) {
          if (!veterinaireId) {
            return res.status(400).json({
              success: false,
              message: 'Un secrétaire doit être associé à un vétérinaire',
              error: 'MISSING_VETERINAIRE_ID'
            });
          }

          if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
            return res.status(400).json({
              success: false,
              message: 'ID du vétérinaire invalide',
              error: 'INVALID_VETERINAIRE_ID'
            });
          }
        }

        // Génération de l'URL de l'image si présente
        const profilePicture = req.file
          ? `${req.protocol}://${req.get('host')}/uploads/users/${req.file.filename}`
          : undefined;

        // Préparation des données utilisateur
        const userData = {
          firstName,
          lastName,
          username,
          email,
          password,
          phoneNumber,
          role,
          profilePicture,
          mapsLocation,
          description,
          address: address ? {
            street: address.street,
            city: address.city,
            state: address.state,
            country: address.country,
            postalCode: address.postalCode
          } : undefined,
          details: details ? {
            services: details.services || [],
            workingHours: details.workingHours || [],
            specialization: details.specialization,
            experienceYears: details.experienceYears || 0
          } : undefined,
          ...(role === UserRole.SECRETAIRE && { veterinaireId }),
          isActive: true,
          rating: role === UserRole.VETERINAIRE ? 0 : undefined,
          
        };

        // Création de l'utilisateur
        const createdUser = await UserService.createUser(userData);

        // Génération des tokens
        const tokens = await AuthService.generateTokens(createdUser);

        // Construction de la réponse sécurisée
        const safeUser = {
          id: createdUser._id.toString(),
          role: createdUser.role,
          firstName: createdUser.firstName,
          lastName: createdUser.lastName,
          email: createdUser.email,
          username: createdUser.username,
          phoneNumber: createdUser.phoneNumber,
          profilePicture: createdUser.profilePicture,
          address: createdUser.address,
          details: createdUser.details,
          mapsLocation: createdUser.mapsLocation,
          description: createdUser.description,
          isActive: createdUser.isActive,
          createdAt: createdUser.createdAt,
          updatedAt: createdUser.updatedAt,
          ...(role === UserRole.SECRETAIRE && { veterinaireId: createdUser.veterinaireId })
        };

        res.status(201).json({
          success: true,
          message: `${role} créé avec succès`,
          user: safeUser,
          tokens: {
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
          }
        });

      } catch (error: any) {
        console.error('Erreur lors de l\'inscription:', error);
        
        // Gestion des erreurs de duplication
        if (error.code === 11000) {
          const duplicateField = error.message.includes('email') ? 'email' : 
                               error.message.includes('username') ? 'username' : 'phoneNumber';
          return res.status(409).json({
            success: false,
            message: `Ce ${duplicateField} est déjà utilisé`,
            error: 'DUPLICATE_ENTRY'
          });
        }

        // Gestion spécifique pour les erreurs de référence (vétérinaire non trouvé)
        if (error.message.includes('veterinaireId')) {
          return res.status(404).json({
            success: false,
            message: 'Le vétérinaire spécifié n\'existe pas',
            error: 'VETERINAIRE_NOT_FOUND'
          });
        }

        // Gestion des autres erreurs
        res.status(500).json({
          success: false,
          message: "Erreur lors de la création du compte",
          error: error.message,
          ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
        });
      }
    });
  };
};


export const loginHandler: RequestHandler = async (req, res, next) => {
  try {
    const { username, password } = req.body as LoginRequest;
    
    if (!username || !password) {
      res.status(400).json({
        success: false,
        message: getErrorMessage("MISSING_CREDENTIALS"),
        error: "MISSING_CREDENTIALS"
      });
      return;
    }

    const auth = await AuthService.authenticate({
      username: username.trim().toLowerCase(),
      password: password.trim()
    });

    res.status(200).json({
      success: true,
      message: "Connexion réussie",
      tokens: {
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken
      },
      user: auth.user
    });

  } catch (error: unknown) {
    const { status, code, message } = handleControllerError(error);
    
    res.status(status).json({
      success: false,
      message,
      error: code
    });
  }
};

export const refreshTokenHandler: RequestHandler = async (req, res, next) => {
  try {
    const { refreshToken } = req.body as RefreshTokenRequest;
    
    if (!refreshToken?.trim()) {
      res.status(400).json({
        success: false,
        message: getErrorMessage("MISSING_TOKEN"),
        error: "MISSING_TOKEN"
      });
      return;
    }

    const tokens = await AuthService.refreshToken(refreshToken.trim());

    res.status(200).json({
      success: true,
      message: "Token rafraîchi",
      tokens: {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken
      }
    });

  } catch (error: unknown) {
    const { status, code, message } = handleControllerError(error);
    
    res.status(status).json({
      success: false,
      message,
      error: code
    });
  }
};

export const logoutHandler: RequestHandler = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({
        success: false,
        message: getErrorMessage("MISSING_TOKEN"),
        error: "MISSING_TOKEN"
      });
      return;
    }
    const token = authHeader.slice(7);
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as { id: string };
    
    if (!Types.ObjectId.isValid(payload.id)) {
      res.status(401).json({
        success: false,
        message: "ID utilisateur invalide",
        error: "INVALID_TOKEN"
      });
      return;
    }
    await AuthService.logout(payload.id);
    res.status(200).json({ 
      success: true, 
      message: "Déconnexion réussie" 
    });
  } catch (error: unknown) {
    const { status, code, message } = handleControllerError(error);
    res.status(status).json({
      success: false,
      message,
      error: code
    });
  }
};
export const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  const { status, code, message } = handleControllerError(err);
  res.status(status).json({
    success: false,
    message,
    error: code,
    ...(process.env.NODE_ENV === 'development' && {
      debug: {
        stack: err instanceof Error ? err.stack : undefined,
        ...(err instanceof mongoose.Error.ValidationError && { errors: (err as any).errors })
      }
    })
  });
};
//#endregion
export const signupClient = signupHandler(UserRole.CLIENT);
export const signupVeterinaire = signupHandler(UserRole.VETERINAIRE);
export const signupAdmin = signupHandler(UserRole.ADMIN);
export const signupSecretaire = signupHandler(UserRole.SECRETAIRE);