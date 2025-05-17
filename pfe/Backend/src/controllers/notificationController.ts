import { Request, Response, NextFunction } from "express";
import Notification from "../models/Notification";
import { UserTokenPayload } from "../middlewares/authMiddleware";
import mongoose from "mongoose";

declare module "express" {
  interface Request {
    user?: UserTokenPayload;
  }
}

export const getUserNotifications = async (
  req: Request,
  res: Response,
  
): Promise<void> => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, message: "Utilisateur non authentifié" });
      return;
    }

    const notifications = await Notification.find({ userId: user.id })
      .sort({ createdAt: -1 })
      .limit(50)
      .populate("appointmentId", "date type caseDescription");

    res.status(200).json({
      success: true,
      notifications,
      count: notifications.length,
    });
  } catch (error) {
    console.error("[getUserNotifications] Error:", error);
    
  }
};

export const markNotificationAsRead = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const user = req.user;

    if (!user) {
      res.status(401).json({ success: false, message: "Utilisateur non authentifié" });
      return;
    }

    if (!mongoose.Types.ObjectId.isValid(id)) {
      res.status(400).json({ success: false, message: "ID de notification invalide" });
      return;
    }

    const notification = await Notification.findOneAndUpdate(
      { _id: id, userId: user.id },
      { read: true },
      { new: true }
    );

    if (!notification) {
      res.status(404).json({ success: false, message: "Notification non trouvée ou non autorisée" });
      return;
    }

    res.status(200).json({ success: true, notification, message: "Notification marquée comme lue" });
  } catch (error) {
    console.error("[markNotificationAsRead] Error:", error);
    next(error);
  }
};