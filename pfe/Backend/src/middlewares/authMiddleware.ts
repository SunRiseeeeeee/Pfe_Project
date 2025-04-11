import { Request, Response, NextFunction, RequestHandler } from "express";
import jwt from "jsonwebtoken";

interface JwtPayload {
  id: string;
  role: string;
  iat?: number;
  exp?: number;
}

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

export const authenticateToken: RequestHandler = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const authHeader = req.headers['authorization'];
  const token = authHeader?.split(' ')[1];

  if (!token) {
    res.status(401).json({ 
      message: "Authentification requise",
      code: "MISSING_TOKEN"
    });
    return;
  }

  if (!process.env.JWT_SECRET) {
    console.error('JWT_SECRET non configuré');
    res.status(500).json({
      message: "Erreur de configuration serveur",
      code: "SERVER_ERROR"
    });
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET) as JwtPayload;
    
    if (!decoded.id || !decoded.role) {
      res.status(403).json({
        message: "Token malformé",
        code: "INVALID_TOKEN_FORMAT"
      });
      return;
    }

    req.user = {
      id: decoded.id,
      role: decoded.role
    };

    next();
  } catch (error) {
    console.error('Erreur d\'authentification:', error);

    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({
        message: "Session expirée",
        code: "TOKEN_EXPIRED"
      });
      return;
    }

    if (error instanceof jwt.JsonWebTokenError) {
      res.status(403).json({
        message: "Token invalide",
        code: "INVALID_TOKEN"
      });
      return;
    }

    res.status(500).json({
      message: "Erreur d'authentification",
      code: "AUTH_ERROR"
    });
  }
};