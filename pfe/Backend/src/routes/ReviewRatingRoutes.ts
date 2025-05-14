import { Router, Request, Response, NextFunction } from "express";
import RatingController from "../controllers/RatingController";
import ReviewController from "../controllers/ReviewController";

const router = Router();

// Routes pour les notes (ratings)
router.post(
  "/ratings/:veterinaireId",
  (req: Request, res: Response, next: NextFunction) => {
    RatingController.addRating(req, res).catch(next);
  }
);
router.put(
    "/ratings/:veterinaireId/:ratingId",
    (req: Request, res: Response, next: NextFunction) => {
      RatingController.updateRating(req, res).catch(next);
    }
  );
  
router.delete(
  "/ratings/:veterinaireId/:ratingId",
  (req: Request, res: Response, next: NextFunction) => {
    RatingController.deleteRating(req, res).catch(next);
  }
);
router.get(
  "/ratings/:veterinaireId",
  (req: Request, res: Response, next: NextFunction) => {
    RatingController.getRatings(req, res).catch(next);
  }
);

// Routes pour les avis (reviews)
router.post(
  "/reviews/:veterinaireId",
  (req: Request, res: Response, next: NextFunction) => {
    ReviewController.addReview(req, res).catch(next);
  }
);
router.put(
    "/reviews/:veterinaireId/:reviewId",  // Route avec les paramètres "veterinaireId" et "reviewId"
    (req: Request, res: Response, next: NextFunction) => {
      ReviewController.updateReview(req, res).catch(next);
    }
  );
  
router.delete(
  "/reviews/:veterinaireId/:reviewId",
  (req: Request, res: Response, next: NextFunction) => {
    ReviewController.deleteReview(req, res).catch(next);
  }
);
router.get(
  "/reviews/:veterinaireId",
  (req: Request, res: Response, next: NextFunction) => {
    ReviewController.getReviews(req, res).catch(next);
  }
);

export default router;