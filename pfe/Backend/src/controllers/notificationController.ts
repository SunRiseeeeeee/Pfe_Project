import { Request, Response, NextFunction } from "express";
import Notification from "../models/Notification";
import { UserTokenPayload } from "../middlewares/authMiddleware";
import mongoose from "mongoose";

declare module "express" {
  interface Request {
    user?: UserTokenPayload;
  }
}


export const getUserNotifications = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.params.userId;  // si tu passes l'ID client dans l'URL
    if (!userId) {
      res.status(400).json({ success: false, message: "ID utilisateur manquant" });
      return;
    }

    // Récupérer les notifications de l'utilisateur triées par date
    const notifications = await Notification.find({ userId })
      .sort({ createdAt: -1 })
      .limit(50)
      .populate("appointmentId", "date type caseDescription");

    // Compter le nombre de notifications non lues
    const unreadCount = await Notification.countDocuments({ userId, read: false });

    res.status(200).json({
      success: true,
      notifications,
      count: notifications.length,
      unreadCount,  // <-- nombre notifications non lues
    });
  } catch (error) {
    console.error("[getUserNotifications] Error:", error);
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};


/**
 * Marquer une notification comme lue via son ID
 */
export const markNotificationAsRead = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      res.status(400).json({ success: false, message: "ID de notification invalide" });
      return;
    }

    const notification = await Notification.findByIdAndUpdate(
      id,
      { read: true },
      { new: true }
    );

    if (!notification) {
      res.status(404).json({ success: false, message: "Notification non trouvée" });
      return;
    }

    res.status(200).json({
      success: true,
      notification,
      message: "Notification marquée comme lue",
    });
  } catch (error) {
    console.error("[markNotificationAsRead] Error:", error);
    next(error);
  }
};

