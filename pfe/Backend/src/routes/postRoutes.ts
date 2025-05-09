import express from 'express';
import {
  createPost,
  updatePost,
  deletePost,
  getVeterinairePosts,
  getAllPosts,
  addReaction,
  deleteReaction,
  getReactionsSummary,
} from '../controllers/PostController';
import { postUpload } from '../services/PostMulterConfig';

const router = express.Router();

// Créer un post
router.post('/veterinaire/:veterinaireId',postUpload,async (req, res) => {await createPost(req, res);});

// Mettre à jour un post
router.put('/veterinaire/:veterinaireId/:id',postUpload,async (req, res) => {await updatePost(req, res);});

// Supprimer un post
router.delete('/veterinaire/:veterinaireId/:id',async (req, res) => {await deletePost(req, res);});

// Récupérer tous les posts d'un vétérinaire
router.get('/veterinaire/:veterinaireId',async (req, res) => {await getVeterinairePosts(req, res);});

// Récupérer tous les posts
router.get('/',async (req, res) => {await getAllPosts(req, res);});

// 📌 Ajouter ou mettre à jour une réaction à un post
router.post(
  '/:postId/reaction',
  async (req, res) => { await addReaction(req, res); }
);

// 📌 Supprimer une réaction d'un post
router.delete(
  '/:postId/reaction',
  async (req, res) => { await deleteReaction(req, res); }
);

// 📌 Récupérer le résumé des réactions d'un post
router.get(
  '/:postId/reactions/summary',
  async (req, res) => { await getReactionsSummary(req, res); }
);


export default router;
