import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

export const verifyToken = (req: Request, res: Response, next: NextFunction) => {
    const token = req.header("Authorization")?.split(" ")[1]; // Extract token from "Bearer <token>"

    if (!token) {
        return res.status(401).json({ message: "Accès refusé, token manquant" });
    }

    try {
        const verified = jwt.verify(token, process.env.JWT_SECRET || "secret");
        (req as any).user = verified; // Store user info in request
        next();
    } catch (error) {
        res.status(403).json({ message: "Token invalide ou expiré" });
    }
};
