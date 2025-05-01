import { Request, Response, NextFunction, RequestHandler, ErrorRequestHandler } from "express";
import mongoose, { Types } from "mongoose";
import jwt from "jsonwebtoken";
import { AuthService, UserService } from "../services/userService";
import { UserRole } from "../types";
import { IUser } from "../models/User";

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
export const signupHandler = (role: UserRole): RequestHandler => {
  const handler: RequestHandler = async (req, res, next) => {
    try {
      // 1. Validation des champs obligatoires avec vérification de type
      const body = req.body as SignupRequest;
      
      const requiredFields = {
        firstName: body.firstName,
        lastName: body.lastName,
        username: body.username,
        email: body.email,
        password: body.password,
        phoneNumber: body.phoneNumber
      };

      // Validation et nettoyage des champs
      const validated = {
        firstName: validateRequiredString(body.firstName, "firstName"),
        lastName: validateRequiredString(body.lastName, "lastName"),
        username: validateRequiredString(body.username, "username").toLowerCase(),
        email: validateRequiredString(body.email, "email").toLowerCase(),
        password: validateRequiredString(body.password, "password"),
        phoneNumber: validateRequiredString(body.phoneNumber, "phoneNumber")
      };

      // Validation des formats
      validateUsernameFormat(validated.username);
      validateEmailFormat(validated.email);
      validatePhoneFormat(validated.phoneNumber);

      // 2. Préparation des données optionnelles
      const extraDetails = buildExtraDetails(role, body);

      // 3. Création de l'utilisateur avec les données validées
      const user = await UserService.createUser(
        { 
          ...validated,
          role
        },
        extraDetails
      );

      // 4. Vérification améliorée de la création
      if (!user || !user._id) {
        console.error('Erreur de création - Objet utilisateur:', user);
        throw new Error("SERVER_ERROR: Échec de la création de l'utilisateur");
      }

      // 5. Conversion explicite de l'ID
      const userId = user._id.toString();
      if (!userId) {
        throw new Error("SERVER_ERROR: Conversion d'ID échouée");
      }

      // 6. Formatage de la réponse
      const userResponse: SafeUserInfo = {
        id: userId,
        role: user.role,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        username: user.username,
        phoneNumber: user.phoneNumber,
        ...(user.profilePicture && { profilePicture: user.profilePicture }),
        ...(user.address && { address: user.address }),
        ...(user.details && { details: user.details }),
        ...(user.mapsLocation && { mapsLocation: user.mapsLocation }),
        ...(user.description && { description: user.description }),
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      };

      // 7. Réponse réussie avec vérification finale
      if (!userResponse.id) {
        throw new Error("SERVER_ERROR: Formatage de réponse échoué");
      }

      res.status(201).json({
        success: true,
        message: `${role} inscrit avec succès`,
        user: userResponse
      });

    } catch (error: unknown) {
      // Gestion d'erreur améliorée avec plus de détails
      let status = 500;
      let code = "SERVER_ERROR";
      let errorMessage = "Erreur serveur";

      if (error instanceof mongoose.Error.ValidationError) {
        status = 400;
        code = "VALIDATION_ERROR";
        errorMessage = error.message;
      } else if (error instanceof Error) {
        if (error.message.includes('VALIDATION_ERROR')) {
          status = 400;
          code = "VALIDATION_ERROR";
          errorMessage = error.message.replace('VALIDATION_ERROR: ', '');
        } else if (error.message.includes('DUPLICATE_USER')) {
          status = 409;
          code = "DUPLICATE_USER";
          errorMessage = "Un utilisateur avec ces informations existe déjà";
        } else if (error.message.includes('SERVER_ERROR')) {
          // Ajout de logs pour les erreurs serveur
          console.error('Erreur serveur détaillée:', {
            message: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString()
          });
          errorMessage = "Problème lors de la création du compte";
        }
      }

      const response: AuthResponse = {
        success: false,
        message: errorMessage,
        error: code,
        ...(process.env.NODE_ENV === 'development' && {
          debug: {
            stack: error instanceof Error ? error.stack : undefined,
            ...(error instanceof mongoose.Error.ValidationError && { 
              errors: (error as any).errors 
            }),
            // Ajout d'informations supplémentaires en développement
            timestamp: new Date().toISOString(),
            receivedData: process.env.NODE_ENV === 'development' ? req.body : undefined
          }
        })
      };

      res.status(status).json(response);
    }
  };
  return handler;
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
export const signupSecretaire = signupHandler(UserRole.SECRETAIRE);
export const signupAdmin = signupHandler(UserRole.ADMIN);