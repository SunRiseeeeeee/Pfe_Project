import { Request, Response } from "express";
import mongoose from "mongoose";
import User, { UserRole } from "../models/User";
import ReviewRating from "../models/Review";

// Contrôleur pour la gestion des Avis et Notes
class ReviewRatingController {

  // Ajouter un avis et mettre à jour la moyenne du vétérinaire
  static async addReviewRating(req: Request, res: Response): Promise<void> {
    try {
      const { veterinaireId } = req.params;
      const { rating, review } = req.body;
      const clientId = req.user?.id;

      // Validation des ObjectId
      if (!clientId || !mongoose.Types.ObjectId.isValid(veterinaireId) || !mongoose.Types.ObjectId.isValid(clientId)) {
        res.status(400).json({ message: "ID invalide" });
        return;
      }
      // Validation de la note
      if (typeof rating !== 'number' || rating < 0 || rating > 5) {
        res.status(400).json({ message: "La note doit être un nombre entre 0 et 5" });
        return;
      }

      // Vérification du rôle vétérinaire
      const vet = await User.findById(veterinaireId);
      if (!vet || vet.role !== UserRole.VETERINAIRE) {
        res.status(404).json({ message: "Vétérinaire non trouvé" });
        return;
      }

      // Vérification de doublon
      const exists = await ReviewRating.findOne({ client: clientId, veterinarian: veterinaireId });
      if (exists) {
        res.status(400).json({ message: "Vous avez déjà noté ce vétérinaire" });
        return;
      }

      // Création du nouvel avis
      const newReview = new ReviewRating({ client: clientId, veterinarian: veterinaireId, rating, review, ratingCount: 0 });
      await newReview.save();

      // Recalcul de la moyenne et du nombre de notes
      const stats = await ReviewRating.aggregate([
        { $match: { veterinarian: new mongoose.Types.ObjectId(veterinaireId) } },
        { $group: { _id: null, avgRating: { $avg: "$rating" }, count: { $sum: 1 } } }
      ]);

      const avg = stats.length ? parseFloat(stats[0].avgRating.toFixed(2)) : 0;
      const cnt = stats.length ? stats[0].count : 0;

      await User.updateOne(
        { _id: veterinaireId },
        { $set: { rating: avg, ratingCount: cnt } }
      );

      res.status(201).json({ message: "Avis ajouté avec succès", review: newReview });

    } catch (err: unknown) {
      console.error("Erreur lors de l'ajout d'un avis:", err);
      const message = err instanceof Error ? err.message : "Erreur serveur";
      res.status(500).json({ message: "Erreur serveur", error: message });
    }
  }

  // Mettre à jour un avis et recalculer la moyenne
  static async updateReviewRating(req: Request, res: Response): Promise<void> {
    try {
      const { reviewId } = req.params;
      const { rating, review } = req.body;
      const clientId = req.user?.id;

      if (!clientId || !mongoose.Types.ObjectId.isValid(reviewId)) {
        res.status(400).json({ message: "ID invalide" });
        return;
      }

      const existingReview = await ReviewRating.findOne({ _id: reviewId, client: clientId });
      if (!existingReview) {
        res.status(404).json({ message: "Avis non trouvé" });
        return;
      }

      // Mise à jour de la note et/ou du texte
      if (rating !== undefined) {
        if (typeof rating !== 'number' || rating < 0 || rating > 5) {
          res.status(400).json({ message: "La note doit être un nombre entre 0 et 5" });
          return;
        }
        existingReview.rating = rating;
      }
      if (review !== undefined) existingReview.review = review;

      await existingReview.save();

      // Recalculer la moyenne après mise à jour
      const veterinaireId = existingReview.veterinarian.toString();
      const stats = await ReviewRating.aggregate([
        { $match: { veterinarian: new mongoose.Types.ObjectId(veterinaireId) } },
        { $group: { _id: null, avgRating: { $avg: "$rating" }, count: { $sum: 1 } } }
      ]);

      const avg = stats.length ? parseFloat(stats[0].avgRating.toFixed(2)) : 0;
      const cnt = stats.length ? stats[0].count : 0;

      await User.updateOne(
        { _id: veterinaireId },
        { $set: { rating: avg, ratingCount: cnt } }
      );

      res.status(200).json({ message: "Avis mis à jour avec succès", review: existingReview });

    } catch (err: unknown) {
      console.error("Erreur mise à jour de l'avis:", err);
      const message = err instanceof Error ? err.message : "Erreur serveur";
      res.status(500).json({ message: "Erreur serveur", error: message });
    }
  }

  // Supprimer un avis et recalculer la moyenne
  static async deleteReviewRating(req: Request, res: Response): Promise<void> {
    try {
      const { reviewId } = req.params;
      const clientId = req.user?.id;

      if (!clientId || !mongoose.Types.ObjectId.isValid(reviewId)) {
        res.status(400).json({ message: "ID invalide" });
        return;
      }

      const deleted = await ReviewRating.findOneAndDelete({ _id: reviewId, client: clientId });
      if (!deleted) {
        res.status(404).json({ message: "Avis non trouvé" });
        return;
      }

      // Recalculer la moyenne après suppression
      const veterinaireId = deleted.veterinarian.toString();
      const stats = await ReviewRating.aggregate([
        { $match: { veterinarian: new mongoose.Types.ObjectId(veterinaireId) } },
        { $group: { _id: null, avgRating: { $avg: "$rating" }, count: { $sum: 1 } } }
      ]);

      const avg = stats.length ? parseFloat(stats[0].avgRating.toFixed(2)) : 0;
      const cnt = stats.length ? stats[0].count : 0;

      await User.updateOne(
        { _id: veterinaireId },
        { $set: { rating: avg, ratingCount: cnt } }
      );

      res.status(200).json({ message: "Avis supprimé avec succès" });

    } catch (err: unknown) {
      console.error("Erreur lors de la suppression de l'avis:", err);
      const message = err instanceof Error ? err.message : "Erreur serveur";
      res.status(500).json({ message: "Erreur serveur", error: message });
    }
  }

  // Récupérer les avis d'un vétérinaire
  static async getReviewsAndRatings(req: Request, res: Response): Promise<void> {
    try {
      const { veterinaireId } = req.params;
      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        res.status(400).json({ message: "ID de vétérinaire invalide" });
        return;
      }

      // Récupérer tous les avis
      const reviews = await ReviewRating
        .find({ veterinarian: veterinaireId })
        .populate("client", "firstName lastName profilePicture");

      // Calculer moyenne et nombre de notes
      const stats = await ReviewRating.aggregate([
        { $match: { veterinarian: new mongoose.Types.ObjectId(veterinaireId) } },
        { $group: { _id: null, avgRating: { $avg: "$rating" }, count: { $sum: 1 } } }
      ]);
      const averageRating = stats.length ? parseFloat(stats[0].avgRating.toFixed(2)) : 0;
      const ratingCount = stats.length ? stats[0].count : 0;

      res.status(200).json({
        reviews,
        averageRating,
        ratingCount
      });
    } catch (err: unknown) {
      console.error("Erreur récupération des avis:", err);
      const message = err instanceof Error ? err.message : "Erreur serveur";
      res.status(500).json({ message: "Erreur serveur", error: message });
    }
  }
}


export { ReviewRatingController };
export default ReviewRatingController;
