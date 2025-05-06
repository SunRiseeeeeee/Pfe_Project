import { Request, Response, NextFunction, RequestHandler, ErrorRequestHandler } from "express";
import mongoose, { Types } from "mongoose";
import jwt from "jsonwebtoken";
import { AuthService, UserService } from "../services/userService";
import { UserRole } from "../types";
import User, { IUser } from "../models/User";
import bcrypt from "bcryptjs";
import { upload } from "../services/multerConfig";

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
  MISSING_FIELD: (field?: string) => `Le champ ${field ? '${field}' : ''} est requis.`,
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

  if (role === UserRole.VETERINAIRE) {
    details.rating = 0;
  }

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

export const signupSecretaire: RequestHandler = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { firstName, lastName, username, email, password, phoneNumber } = req.body;
    const { veterinaireId } = req.params;

    // Validation de l'ID du vétérinaire
    if (!veterinaireId) {
      res.status(400).json({ message: "L'ID du vétérinaire est requis." });
      return;
    }

    const veterinaire = await User.findById(veterinaireId);
    if (!veterinaire || veterinaire.role !== UserRole.VETERINAIRE) {
      res.status(400).json({ message: "Vétérinaire introuvable ou rôle invalide." });
      return;
    }

    // Vérification de l'unicité de l'email et du username
    const exists = await User.findOne({ $or: [{ username }, { email }] });
    if (exists) {
      res.status(409).json({ message: "Username ou email déjà utilisé." });
      return;
    }

    // Hashage du mot de passe
    const hashed = await bcrypt.hash(password, 12);

    // Gestion de l'image (si présente)
    const profilePicture = req.file ? `uploads/${req.file.filename}` : undefined;

    // Création du nouveau secrétaire
    const newSecretaire = new User({
      firstName,
      lastName,
      username,
      email,
      password: hashed,
      phoneNumber,
      role: UserRole.SECRETAIRE,
      veterinaireId,
      ...(profilePicture && { profilePicture }), // Ajouter l'image si présente
    });

    await newSecretaire.save();

    // Réponse après la création
    res.status(201).json({
      message: "Secrétaire créée avec succès.",
      user: {
        id: newSecretaire._id,
        firstName: newSecretaire.firstName,
        lastName: newSecretaire.lastName,
        username: newSecretaire.username,
        email: newSecretaire.email,
        phoneNumber: newSecretaire.phoneNumber,
        ...(newSecretaire.profilePicture && { profilePicture: newSecretaire.profilePicture }),
      },
    });
  } catch (err) {
    next(err); // Passer l'erreur au middleware d'erreur
  }
};

export const signupHandler = async (req: Request, res: Response, next: NextFunction, role: UserRole): Promise<Response> => {
  try {
    // Extraction des champs du corps de la requête
    const { firstName, lastName, username, email, password, phoneNumber } = req.body;

    // Validation des champs obligatoires
    const requiredFields = { firstName, lastName, username, email, password, phoneNumber };
    const missingFields = Object.entries(requiredFields)
      .filter(([_, value]) => !value)
      .map(([key]) => key);

    if (missingFields.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Champs obligatoires manquants: ${missingFields.join(', ')}`,
        error: 'MISSING_FIELDS',
      });
    }

    // Validation des formats des champs (username, email, phoneNumber)
    try {
      validateUsernameFormat(username);
      validateEmailFormat(email);
      validatePhoneFormat(phoneNumber);
    } catch (validationError) {
      return res.status(400).json({
        success: false,
        message: validationError instanceof Error ? validationError.message : 'Format de données invalide',
        error: 'VALIDATION_ERROR',
      });
    }

    // Gestion de l'image (si présente)
    const profilePicture = req.file ? `uploads/${req.file.filename}` : undefined; // image est optionnelle

    // Construction des données utilisateur
    const userData = {
      firstName,
      lastName,
      username,
      email,
      password,
      phoneNumber,
      role,
      ...(profilePicture && { profilePicture }), // Si profilePicture existe, l'ajouter
    };

    // Ajouter les détails spécifiques au rôle (ex: secrétaire, vétérinaire, etc.)
    const extraDetails = buildExtraDetails(role, req.body);

    // Création de l'utilisateur via le service
    const newUser = await UserService.createUser(userData, extraDetails);

    if (!newUser?._id) {
      throw new Error("USER_CREATION_FAILED");
    }

    // Réponse après l'inscription réussie
    const userResponse = {
      id: newUser._id.toString(),
      role: newUser.role,
      firstName: newUser.firstName,
      lastName: newUser.lastName,
      email: newUser.email,
      username: newUser.username,
      phoneNumber: newUser.phoneNumber,
      createdAt: newUser.createdAt,
      updatedAt: newUser.updatedAt,
      ...(newUser.profilePicture && { profilePicture: newUser.profilePicture }),
    };

    return res.status(201).json({
      success: true,
      message: `${role} inscrit avec succès`,
      user: userResponse,
    });

  } catch (error) {
    // Gestion des erreurs connues
    if (error instanceof mongoose.Error.ValidationError) {
      return res.status(400).json({
        success: false,
        message: error.message,
        error: 'VALIDATION_ERROR',
      });
    }

    if (error instanceof Error && error.message.includes('DUPLICATE_USER')) {
      return res.status(409).json({
        success: false,
        message: 'Un utilisateur avec ces informations existe déjà',
        error: 'DUPLICATE_USER',
      });
    }

    // Gestion des autres erreurs générales
    console.error(`[${new Date().toISOString()}] Signup Error:`, error);

    const errorResponse = {
      success: false,
      message: 'Erreur lors de la création du compte',
      error: 'SERVER_ERROR',
      ...(process.env.NODE_ENV === 'development' && {
        debug: {
          message: error instanceof Error ? error.message : 'Unknown error',
          stack: error instanceof Error ? error.stack : undefined,
        },
      }),
    };

    return res.status(500).json(errorResponse);
  }
};

export const signupClient: RequestHandler = async (req: Request, res: Response, next: NextFunction) => {
  await signupHandler(req, res, next, UserRole.CLIENT);
};

export const signupVeterinaire: RequestHandler = async (req: Request, res: Response, next: NextFunction) => {
  await signupHandler(req, res, next, UserRole.VETERINAIRE);
};

export const signupAdmin: RequestHandler = async (req: Request, res: Response, next: NextFunction) => {
  await signupHandler(req, res, next, UserRole.ADMIN);
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