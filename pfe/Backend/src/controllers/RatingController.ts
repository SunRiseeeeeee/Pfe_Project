import { Request, Response } from "express";
import mongoose from "mongoose";
import User from "../models/User";
import Rating from "../models/Rating";

class RatingController {
  static async addRating(req: Request, res: Response): Promise<Response> {
    try {
      const { veterinaireId } = req.params;
      const { rating, clientId } = req.body;

      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        return res.status(400).json({ success: false, message: "ID du vétérinaire invalide" });
      }

      if (!clientId || !mongoose.Types.ObjectId.isValid(clientId)) {
        return res.status(400).json({ success: false, message: "ID du client invalide" });
      }

      const numericRating = Number(rating);
      if (isNaN(numericRating) || numericRating < 1 || numericRating > 5) {
        return res.status(400).json({ success: false, message: "La note doit être un nombre entre 1 et 5" });
      }

      const existingRating = await Rating.findOne({ client: clientId, veterinarian: veterinaireId });
      if (existingRating) {
        return res.status(400).json({ success: false, message: "Vous avez déjà donné une note à ce vétérinaire" });
      }

      const newRating = new Rating({
        client: clientId,
        veterinarian: veterinaireId,
        rating: numericRating,
      });

      await newRating.save();
      await this.updateVeterinarianStats(veterinaireId);

      return res.status(201).json({
        success: true,
        message: "Note ajoutée avec succès",
        data: newRating,
      });

    } catch (err: unknown) {
      console.error("Erreur addRating:", err);
      return this.handleServerError(res, err);
    }
  }

  static async getRatings(req: Request, res: Response): Promise<Response> {
    try {
      const { veterinaireId } = req.params;

      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        return res.status(400).json({ success: false, message: "ID du vétérinaire invalide" });
      }

      const ratings = await Rating.find({ veterinarian: veterinaireId })
        .populate("client", "firstName lastName profilePicture")
        .sort({ createdAt: -1 });

      const stats = await this.calculateRatingStats(veterinaireId);

      return res.status(200).json({
        success: true,
        count: ratings.length,
        averageRating: stats.averageRating,
        ratingCount: stats.ratingCount,
        data: ratings,
      });
    } catch (err: unknown) {
      console.error("Erreur getRatings:", err);
      return this.handleServerError(res, err);
    }
  }

  static async updateRating(req: Request, res: Response): Promise<Response> {
    try {
      const { veterinaireId, ratingId } = req.params;
      const { rating, clientId } = req.body;

      if (!mongoose.Types.ObjectId.isValid(veterinaireId) || !mongoose.Types.ObjectId.isValid(ratingId)) {
        return res.status(400).json({ success: false, message: "ID invalide (vétérinaire ou note)" });
      }

      const existingRating = await Rating.findOne({
        _id: ratingId,
        veterinarian: veterinaireId,
        client: clientId,
      });

      if (!existingRating) {
        return res.status(404).json({ success: false, message: "Note non trouvée" });
      }

      if (typeof rating !== "number" || rating < 1 || rating > 5) {
        return res.status(400).json({ success: false, message: "La note doit être un nombre entre 1 et 5" });
      }

      existingRating.rating = rating;
      existingRating.updatedAt = new Date();
      await existingRating.save();
      await this.updateVeterinarianStats(veterinaireId);

      return res.status(200).json({
        success: true,
        message: "Note mise à jour avec succès",
        data: existingRating,
      });
    } catch (err: unknown) {
      console.error("Erreur updateRating:", err);
      return this.handleServerError(res, err);
    }
  }

  static async deleteRating(req: Request, res: Response): Promise<Response> {
    try {
      const { veterinaireId, ratingId } = req.params;
      const { clientId } = req.body;

      if (!mongoose.Types.ObjectId.isValid(veterinaireId) || !mongoose.Types.ObjectId.isValid(ratingId)) {
        return res.status(400).json({ success: false, message: "ID invalide (vétérinaire ou note)" });
      }

      const rating = await Rating.findOneAndDelete({
        _id: ratingId,
        veterinarian: veterinaireId,
        client: clientId,
      });

      if (!rating) {
        return res.status(404).json({ success: false, message: "Note non trouvée" });
      }

      await this.updateVeterinarianStats(veterinaireId);

      return res.status(200).json({
        success: true,
        message: "Note supprimée avec succès",
      });
    } catch (err: unknown) {
      console.error("Erreur deleteRating:", err);
      return this.handleServerError(res, err);
    }
  }

  static async calculateRatingStats(veterinaireId: string): Promise<{ averageRating: number, ratingCount: number }> {
    const stats = await Rating.aggregate([
      { $match: { veterinarian: new mongoose.Types.ObjectId(veterinaireId) } },
      { $group: { _id: null, averageRating: { $avg: "$rating" }, ratingCount: { $sum: 1 } } }
    ]);

    return {
      averageRating: stats[0]?.averageRating || 0,
      ratingCount: stats[0]?.ratingCount || 0,
    };
  }

  static async updateVeterinarianStats(veterinaireId: string): Promise<void> {
    const stats = await this.calculateRatingStats(veterinaireId);

    await User.findByIdAndUpdate(veterinaireId, {
      $set: {
        averageRating: stats.averageRating,
        ratingCount: stats.ratingCount,
      }
    });
  }

  private static handleServerError(res: Response, error: unknown): Response {
    const message = error instanceof Error ? error.message : "Erreur serveur inconnue";
    return res.status(500).json({ success: false, message });
  }
}

export default RatingController;