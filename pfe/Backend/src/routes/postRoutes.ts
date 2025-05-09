import express from 'express';
import {
  createPost,
  updatePost,
  deletePost,
  getVeterinairePosts,
  getAllPosts,
} from '../controllers/PostController';
import { postUpload } from '../services/PostMulterConfig';

const router = express.Router();

// Créer un post
router.post(
  '/veterinaire/:veterinaireId',
  postUpload,
  async (req, res) => {
    await createPost(req, res);
  }
);

// Mettre à jour un post
router.put(
  '/veterinaire/:veterinaireId/:id',
  postUpload,
  async (req, res) => {
    await updatePost(req, res);
  }
);

// Supprimer un post
router.delete(
  '/veterinaire/:veterinaireId/:id',
  async (req, res) => {
    await deletePost(req, res);
  }
);

// Récupérer tous les posts d'un vétérinaire
router.get(
  '/veterinaire/:veterinaireId',
  async (req, res) => {
    await getVeterinairePosts(req, res);
  }
);

// Récupérer tous les posts
router.get(
  '/',
  async (req, res) => {
    await getAllPosts(req, res);
  }
);

export default router;
