import { Request, Response } from "express";
import mongoose from "mongoose";
import sanitizeHtml from "sanitize-html";
import User, { UserRole } from "../models/User";
import Review, { IReview } from "../models/Review";

class ReviewController {
  // Ajouter ou mettre à jour un avis
  static async addReview(req: Request, res: Response): Promise<Response> {
    try {
      const { veterinaireId } = req.params;
      const { review, clientId } = req.body;

      // Validation de clientId dans le body
      if (!clientId) {
        console.error("[addReview] Erreur: clientId non fourni dans le body");
        return res.status(400).json({ success: false, message: "ID du client requis dans le body" });
      }
      if (!mongoose.Types.ObjectId.isValid(clientId)) {
        console.error("[addReview] Invalid clientId:", clientId);
        return res.status(400).json({ success: false, message: "ID du client invalide" });
      }

      // Validation de l'ID du vétérinaire
      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        console.error("[addReview] Invalid veterinaireId:", veterinaireId);
        return res.status(400).json({ success: false, message: "ID du vétérinaire invalide" });
      }

      // Vérification des utilisateurs
      const [vet, client] = await Promise.all([
        User.findById(veterinaireId),
        User.findById(clientId),
      ]);
      if (!vet || vet.role !== UserRole.VETERINAIRE) {
        return res.status(404).json({ success: false, message: "Vétérinaire non trouvé ou rôle incorrect" });
      }
      if (!client || client.role !== UserRole.CLIENT) {
        return res.status(400).json({ success: false, message: "Client non trouvé ou rôle incorrect" });
      }

      // Validation et sanitization de l'avis
      if (!review || typeof review !== "string" || review.trim().length < 10) {
        return res.status(400).json({
          success: false,
          message: "L'avis doit contenir au moins 10 caractères",
        });
      }
      if (review.trim().length > 500) {
        return res.status(400).json({
          success: false,
          message: "L'avis ne peut pas dépasser 500 caractères",
        });
      }
      const sanitizedReview = sanitizeHtml(review.trim(), {
        allowedTags: [],
        allowedAttributes: {},
      });
      if (!/\S/.test(sanitizedReview)) {
        return res.status(400).json({
          success: false,
          message: "L'avis ne peut pas contenir uniquement des espaces",
        });
      }
      // Validation : caractères autorisés (français inclus)
      if (!/^[a-zA-Z0-9\s.,!?éèàçùôîêûâëœ\-']+$/.test(sanitizedReview)) {
        return res.status(400).json({
          success: false,
          message: "L'avis contient des caractères non autorisés",
        });
      }
      // Validation : au moins 3 mots
      if (sanitizedReview.split(/\s+/).filter((word) => word.length > 0).length < 3) {
        return res.status(400).json({
          success: false,
          message: "L'avis doit contenir au moins 3 mots",
        });
      }

      // Vérifier si un avis existe déjà pour ce client et vétérinaire
      const existingReview = await Review.findOne({
        client: clientId,
        veterinarian: veterinaireId,
      });

      if (existingReview) {
        // Mettre à jour l'avis existant
        existingReview.review = sanitizedReview;
        existingReview.updatedAt = new Date();
        await existingReview.save();
        return res.status(200).json({
          success: true,
          message: "Avis mis à jour avec succès",
          data: existingReview,
        });
      }

      // Créer un nouvel avis
      const newReview = new Review({
        client: clientId,
        veterinarian: veterinaireId,
        review: sanitizedReview,
      });
      await newReview.save();

      return res.status(201).json({
        success: true,
        message: "Avis ajouté avec succès",
        data: newReview,
      });
    } catch (err: unknown) {
      console.error(
        `[addReview] Erreur (veterinaireId: ${req.params.veterinaireId}, clientId: ${req.body.clientId}, reviewLength: ${
          req.body.review?.length || 0
        })`,
        err
      );
      return this.handleServerError(res, err);
    }
  }

  // Mettre à jour un avis
  static async updateReview(req: Request, res: Response): Promise<Response> {
    try {
      const { reviewId } = req.params;
      const { review, clientId } = req.body;

      // Validation de clientId dans le body
      if (!clientId) {
        console.error("[updateReview] Erreur: clientId non fourni dans le body");
        return res.status(400).json({ success: false, message: "ID du client requis dans le body" });
      }
      if (!mongoose.Types.ObjectId.isValid(clientId)) {
        console.error("[updateReview] Invalid clientId:", clientId);
        return res.status(400).json({ success: false, message: "ID du client invalide" });
      }

      // Validation de l'ID de l'avis
      if (!mongoose.Types.ObjectId.isValid(reviewId)) {
        console.error("[updateReview] Invalid reviewId:", reviewId);
        return res.status(400).json({ success: false, message: "ID d'avis invalide" });
      }

      // Recherche de l'avis existant
      const existingReview = await Review.findOne({ _id: reviewId, client: clientId }) as IReview | null;
      if (!existingReview) {
        return res.status(404).json({ success: false, message: "Avis non trouvé ou non autorisé" });
      }

      // Validation et sanitization de l'avis
      if (!review) {
        return res.status(400).json({
          success: false,
          message: "L'avis ne peut pas être vide",
        });
      }
      if (typeof review !== "string" || review.trim().length < 10) {
        return res.status(400).json({
          success: false,
          message: "L'avis doit contenir au moins 10 caractères",
        });
      }
      if (review.trim().length > 500) {
        return res.status(400).json({
          success: false,
          message: "L'avis ne peut pas dépasser 500 caractères",
        });
      }
      const sanitizedReview = sanitizeHtml(review.trim(), {
        allowedTags: [],
        allowedAttributes: {},
      });
      if (!/\S/.test(sanitizedReview)) {
        return res.status(400).json({
          success: false,
          message: "L'avis ne peut pas contenir uniquement des espaces",
        });
      }
      // Validation : caractères autorisés (français inclus)
      if (!/^[a-zA-Z0-9\s.,!?éèàçùôîêûâëœ\-']+$/.test(sanitizedReview)) {
        return res.status(400).json({
          success: false,
          message: "L'avis contient des caractères non autorisés",
        });
      }
      // Validation : au moins 3 mots
      if (sanitizedReview.split(/\s+/).filter((word) => word.length > 0).length < 3) {
        return res.status(400).json({
          success: false,
          message: "L'avis doit contenir au moins 3 mots",
        });
      }

      // Mise à jour de l'avis
      existingReview.review = sanitizedReview;
      existingReview.updatedAt = new Date();
      await existingReview.save();

      return res.status(200).json({
        success: true,
        message: "Avis mis à jour avec succès",
        data: existingReview,
      });
    } catch (err: unknown) {
      console.error(
        `[updateReview] Erreur (reviewId: ${req.params.reviewId}, clientId: ${req.body.clientId}, reviewLength: ${
          req.body.review?.length || 0
        })`,
        err
      );
      return this.handleServerError(res, err);
    }
  }

  // Supprimer un avis
  static async deleteReview(req: Request, res: Response): Promise<Response> {
    try {
      const { reviewId } = req.params;
      const { clientId } = req.body;

      // Validation de clientId dans le body
      if (!clientId) {
        console.error("[deleteReview] Erreur: clientId non fourni dans le body");
        return res.status(400).json({ success: false, message: "ID du client requis dans le body" });
      }
      if (!mongoose.Types.ObjectId.isValid(clientId)) {
        console.error("[deleteReview] Invalid clientId:", clientId);
        return res.status(400).json({ success: false, message: "ID du client invalide" });
      }

      // Validation de l'ID de l'avis
      if (!mongoose.Types.ObjectId.isValid(reviewId)) {
        console.error("[deleteReview] Invalid reviewId:", reviewId);
        return res.status(400).json({ success: false, message: "ID d'avis invalide" });
      }

      // Suppression de l'avis
      const deleted = await Review.findOneAndDelete({ _id: reviewId, client: clientId });
      if (!deleted) {
        return res.status(404).json({ success: false, message: "Avis non trouvé ou non autorisé" });
      }

      return res.status(200).json({
        success: true,
        message: "Avis supprimé avec succès",
      });
    } catch (err: unknown) {
      console.error(
        `[deleteReview] Erreur (reviewId: ${req.params.reviewId}, clientId: ${req.body.clientId})`,
        err
      );
      return this.handleServerError(res, err);
    }
  }

  // Récupérer les avis d'un vétérinaire
  static async getReviews(req: Request, res: Response): Promise<Response> {
    try {
      const { veterinaireId } = req.params;

      // Validation de l'ID du vétérinaire
      if (!mongoose.Types.ObjectId.isValid(veterinaireId)) {
        console.error("[getReviews] Invalid veterinaireId:", veterinaireId);
        return res.status(400).json({ success: false, message: "ID du vétérinaire invalide" });
      }

      // Vérification que le vétérinaire existe
      const vet = await User.findById(veterinaireId);
      if (!vet || vet.role !== UserRole.VETERINAIRE) {
        return res.status(404).json({ success: false, message: "Vétérinaire non trouvé ou rôle incorrect" });
      }

      // Récupérer les avis
      const reviews = await Review.find({ veterinarian: veterinaireId })
        .populate("client", "firstName lastName username profilePicture")
        .sort({ createdAt: -1 })
        .exec();

      // Compter les clients uniques
      const uniqueClientsCount = new Set(reviews.map((review) => review.client.toString())).size;

      return res.status(200).json({
        success: true,
        message: "Avis récupérés avec succès",
        data: reviews,
        totalReviews: reviews.length,
        totalUniqueClients: uniqueClientsCount,
      });
    } catch (err: unknown) {
      console.error(`[getReviews] Erreur (veterinaireId: ${req.params.veterinaireId})`, err);
      return this.handleServerError(res, err);
    }
  }

  // Gestion des erreurs serveur
  private static handleServerError(res: Response, error: unknown): Response {
    const message = error instanceof Error ? error.message : "Erreur serveur inconnue";
    return res.status(500).json({
      success: false,
      message: "Erreur serveur",
      ...(process.env.NODE_ENV === "development" && { error: message }),
    });
  }
}

export default ReviewController;