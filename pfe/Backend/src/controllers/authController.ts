import { Request, Response, NextFunction, RequestHandler, ErrorRequestHandler } from "express";
import { Types } from "mongoose";
import jwt from "jsonwebtoken";
import { AuthService, UserService } from "../services/userService";
import { UserRole } from "../types";
import { IUser } from "../models/User";

//#region Interfaces
interface WorkingHours {
  day: string;
  start: string;
  end: string;
  pauseStart?: string;
  pauseEnd?: string;
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
  services?: string[];
  workingHours?: WorkingHours[];
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
  address?: {
    street?: string;
    city?: string;
    state?: string;
    country?: string;
    postalCode?: string;
  };
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
}
//#endregion

//#region Constants
const VALID_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] as const;
const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;
const USERNAME_REGEX = /^[a-zA-Z0-9_]+$/;
const EMAIL_REGEX = /^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$/;

enum ErrorCode {
  MISSING_FIELD = "MISSING_FIELD",
  INVALID_EMAIL = "INVALID_EMAIL",
  INVALID_USERNAME = "INVALID_USERNAME",
  INVALID_WORKING_HOURS = "INVALID_WORKING_HOURS",
  MISSING_CREDENTIALS = "MISSING_CREDENTIALS",
  INVALID_CREDENTIALS = "INVALID_CREDENTIALS",
  MISSING_TOKEN = "MISSING_TOKEN",
  INVALID_TOKEN = "INVALID_TOKEN",
  SERVER_ERROR = "SERVER_ERROR",
  ACCOUNT_LOCKED = "ACCOUNT_LOCKED"
}

interface ErrorMessages {
  [ErrorCode.MISSING_FIELD]: string;
  [ErrorCode.INVALID_EMAIL]: string;
  [ErrorCode.INVALID_USERNAME]: string;
  [ErrorCode.INVALID_WORKING_HOURS]: string;
  [ErrorCode.MISSING_CREDENTIALS]: string;
  [ErrorCode.INVALID_CREDENTIALS]: string;
  [ErrorCode.MISSING_TOKEN]: string;
  [ErrorCode.INVALID_TOKEN]: string;
  [ErrorCode.SERVER_ERROR]: string;
  [ErrorCode.ACCOUNT_LOCKED]: string;
}

const ERROR_MESSAGES: ErrorMessages = {
  [ErrorCode.MISSING_FIELD]: "Le champ est requis.",
  [ErrorCode.INVALID_EMAIL]: "L'email est invalide.",
  [ErrorCode.INVALID_USERNAME]: "Le nom d'utilisateur est invalide.",
  [ErrorCode.INVALID_WORKING_HOURS]: "Les heures de travail sont invalides.",
  [ErrorCode.MISSING_CREDENTIALS]: "Identifiants manquants.",
  [ErrorCode.INVALID_CREDENTIALS]: "Identifiants incorrects.",
  [ErrorCode.MISSING_TOKEN]: "Token manquant.",
  [ErrorCode.INVALID_TOKEN]: "Token invalide.",
  [ErrorCode.SERVER_ERROR]: "Erreur serveur.",
  [ErrorCode.ACCOUNT_LOCKED]: "Compte bloqué. Réessayez plus tard."
};

const getErrorMessage = (code: ErrorCode, field?: string): string => {
  const baseMessage = ERROR_MESSAGES[code];
  
  if (code === ErrorCode.MISSING_FIELD && field) {
    return `Le champ '${field}' est requis.`;
  }
  
  if (code === ErrorCode.ACCOUNT_LOCKED && field) {
    return `Compte bloqué. Réessayez dans ${field} minutes.`;
  }
  
  return baseMessage;
};
//#endregion

//#region Helper Functions
const validateRequiredString = (value: unknown, fieldName: string): string => {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(getErrorMessage(ErrorCode.MISSING_FIELD, fieldName));
  }
  return value.trim();
};

const validateEmailFormat = (email: string): void => {
  if (!EMAIL_REGEX.test(email)) {
    throw new Error(getErrorMessage(ErrorCode.INVALID_EMAIL));
  }
};

const validateUsernameFormat = (username: string): void => {
  if (!USERNAME_REGEX.test(username)) {
    throw new Error(getErrorMessage(ErrorCode.INVALID_USERNAME));
  }
};

const sanitizeOptionalString = (value?: unknown): string | undefined => {
  return typeof value === 'string' ? value.trim() : undefined;
};

const validateWorkingHours = (hours: unknown): WorkingHours[] => {
  if (!Array.isArray(hours)) {
    throw new Error(getErrorMessage(ErrorCode.INVALID_WORKING_HOURS));
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

    return { day, start, end, ...(pauseStart && { pauseStart }), ...(pauseEnd && { pauseEnd }) };
  });
};
//#endregion

//#region Controller Handlers
export const signupHandler = (role: UserRole): RequestHandler => async (req: Request<{}, {}, SignupRequest>, res: Response<AuthResponse>, next: NextFunction) => {
  try {
    // Validate required fields
    const firstName = validateRequiredString(req.body.firstName, "firstName");
    const lastName = validateRequiredString(req.body.lastName, "lastName");
    const username = validateRequiredString(req.body.username, "username").toLowerCase();
    const email = validateRequiredString(req.body.email, "email").toLowerCase();
    const password = validateRequiredString(req.body.password, "password");
    const phoneNumber = validateRequiredString(req.body.phoneNumber, "phoneNumber");

    // Validate formats
    validateUsernameFormat(username);
    validateEmailFormat(email);

    // Prepare extra details
    const extraDetails: Partial<IUser> = {
      profilePicture: sanitizeOptionalString(req.body.profilePicture),
      mapsLocation: sanitizeOptionalString(req.body.mapsLocation),
      description: sanitizeOptionalString(req.body.description),
      details: {},
      reviews: []
    };

    // Veterinarian specific fields
    if (role === UserRole.VETERINAIRE) {
      if (req.body.services) {
        extraDetails.details = {
          ...extraDetails.details,
          services: Array.isArray(req.body.services) ? req.body.services : []
        };
      }

      if (req.body.workingHours) {
        extraDetails.details = {
          ...extraDetails.details,
          workingHours: validateWorkingHours(req.body.workingHours)
        };
      }
      extraDetails.rating = 0;
    }

    // Create user
    const user = await UserService.createUser(
      { firstName, lastName, username, email, password, phoneNumber, role },
      extraDetails
    );

    res.status(201).json({
      success: true,
      message: `${role} inscrit avec succès`,
      userId: user._id.toString()
    });

  } catch (error: any) {
    console.error('Signup error:', error);
    const status = error.message.includes('exists') ? 409 : 400;
    res.status(status).json({
      success: false,
      message: error.message,
      error: 'VALIDATION_ERROR'
    });
  }
};

export const loginHandler = async (req: Request<{}, AuthResponse, LoginRequest>, res: Response<AuthResponse>, next: NextFunction): Promise<void> => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      res.status(400).json({
        success: false,
        message: getErrorMessage(ErrorCode.MISSING_CREDENTIALS),
        error: ErrorCode.MISSING_CREDENTIALS
      });
      return;
    }

    const auth = await AuthService.authenticate({
      username: username.trim(),
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

  } catch (error: any) {
    console.error('Login error:', error);
    
    let status = 500;
    let errorCode = ErrorCode.SERVER_ERROR;
    let message = getErrorMessage(ErrorCode.SERVER_ERROR);
    
    if (error.message.includes(ErrorCode.INVALID_CREDENTIALS)) {
      status = 401;
      errorCode = ErrorCode.INVALID_CREDENTIALS;
      message = getErrorMessage(ErrorCode.INVALID_CREDENTIALS);
    } else if (error.message.includes('Account locked')) {
      status = 403;
      errorCode = ErrorCode.ACCOUNT_LOCKED;
      const minutes = error.message.match(/\d+/)?.[0] || '30';
      message = getErrorMessage(ErrorCode.ACCOUNT_LOCKED, minutes);
    }

    res.status(status).json({
      success: false,
      message,
      error: errorCode
    });
  }
};

export const refreshTokenHandler = async (req: Request<{}, AuthResponse, RefreshTokenRequest>, res: Response<AuthResponse>, next: NextFunction): Promise<void> => {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken?.trim()) {
      res.status(400).json({
        success: false,
        message: getErrorMessage(ErrorCode.MISSING_TOKEN),
        error: ErrorCode.MISSING_TOKEN
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

  } catch (error: any) {
    console.error('Refresh token error:', error);
    const status = error.message.includes('expired') ? 401 : 400;
    res.status(status).json({
      success: false,
      message: error.message.includes('expired') 
        ? getErrorMessage(ErrorCode.INVALID_TOKEN)
        : getErrorMessage(ErrorCode.MISSING_TOKEN),
      error: error.message.includes('expired') 
        ? ErrorCode.INVALID_TOKEN 
        : ErrorCode.MISSING_TOKEN
    });
  }
};

export const logoutHandler = async (req: Request, res: Response<AuthResponse>, next: NextFunction): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({
        success: false,
        message: getErrorMessage(ErrorCode.MISSING_TOKEN),
        error: ErrorCode.MISSING_TOKEN
      });
      return;
    }

    const token = authHeader.slice(7);
    const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET!) as { id: string };
    
    if (!Types.ObjectId.isValid(payload.id)) {
      res.status(401).json({
        success: false,
        message: "ID utilisateur invalide",
        error: ErrorCode.INVALID_TOKEN
      });
      return;
    }

    await AuthService.logout(payload.id);
    res.status(200).json({ 
      success: true, 
      message: "Déconnexion réussie" 
    });

  } catch (error: any) {
    console.error('Logout error:', error);
    res.status(401).json({
      success: false,
      message: error.message.includes('expired') 
        ? getErrorMessage(ErrorCode.INVALID_TOKEN)
        : "Erreur de déconnexion",
      error: ErrorCode.INVALID_TOKEN
    });
  }
};

export const errorHandler: ErrorRequestHandler = (err: unknown, req: Request, res: Response<AuthResponse>, next: NextFunction) => {
  console.error("[errorHandler]", err);
  
  let status = 500;
  let message = getErrorMessage(ErrorCode.SERVER_ERROR);
  let errorCode = ErrorCode.SERVER_ERROR;

  if (err instanceof Error) {
    message = err.message;
    
    if (err.message.includes(ErrorCode.INVALID_CREDENTIALS)) {
      status = 401;
      errorCode = ErrorCode.INVALID_CREDENTIALS;
    } else if (err.message.includes('Account locked')) {
      status = 403;
      errorCode = ErrorCode.ACCOUNT_LOCKED;
    } else if (err.message.includes(ErrorCode.MISSING_FIELD) || 
               err.message.includes(ErrorCode.MISSING_CREDENTIALS) || 
               err.message.includes(ErrorCode.MISSING_TOKEN)) {
      status = 400;
    }
  }

  res.status(status).json({
    success: false,
    message,
    error: errorCode
  });
};
//#endregion

//#region Route Exports
export const signupClient = signupHandler(UserRole.CLIENT);
export const signupVeterinaire = signupHandler(UserRole.VETERINAIRE);
export const signupSecretaire = signupHandler(UserRole.SECRETAIRE);
export const signupAdmin = signupHandler(UserRole.ADMIN);
//#endregion