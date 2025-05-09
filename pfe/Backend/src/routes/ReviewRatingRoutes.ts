import express from 'express';
import { authenticateToken } from '../middlewares/authMiddleware';
import ReviewRatingController from '../controllers/ReviewRatingController';

const router = express.Router();

// Utilisation avec .bind() pour préserver le contexte
router.post('/:veterinaireId', authenticateToken, ReviewRatingController.addReviewRating.bind(ReviewRatingController));
router.put('/:reviewId', authenticateToken, ReviewRatingController.updateReviewRating.bind(ReviewRatingController));
router.delete('/:reviewId', authenticateToken, ReviewRatingController.deleteReviewRating.bind(ReviewRatingController));
router.get('/:veterinaireId', ReviewRatingController.getReviewsAndRatings.bind(ReviewRatingController));

export default router;