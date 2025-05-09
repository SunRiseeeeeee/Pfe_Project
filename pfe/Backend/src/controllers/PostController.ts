import { Request, Response } from "express";
import Post from "../models/Post";
import User from "../models/User";
import { postUpload } from "../services/PostMulterConfig";
import fs from "fs";
import path from "path";
import { promisify } from "util";
import { Types } from "mongoose";

const unlinkAsync = promisify(fs.unlink);

// Interface pour typer les réponses des posts
interface IPostResponse {
  _id: Types.ObjectId;
  photo: string;
  description: string;
  createdAt: Date;
  updatedAt: Date;
  veterinaire: {
    _id: Types.ObjectId;
    firstName: string;
    lastName: string;
    profilePicture?: string;
  };
  reactions: {
    counts: {
      total: number;
      "j'aime": number;
      "j'adore": number;
      triste: number;
      "j'admire": number;
    };
    userReactions: Array<{
      type: string;
      user: {
        _id: Types.ObjectId;
        firstName: string;
        lastName: string;
        profilePicture?: string;
      };
    }>;
  };
}

// 📌 Créer un post
export const createPost = async (req: Request, res: Response): Promise<Response> => {
  if (!req.file) {
    return res.status(400).json({ message: "L'image est requise." });
  }

  const { description } = req.body;
  const { veterinaireId } = req.params;

  if (!veterinaireId) {
    return res.status(400).json({ message: "Le champ veterinaireId est requis." });
  }

  try {
    const newPost = await Post.create({
      photo: req.file.filename,
      description,
      veterinaireId,
      createdBy: veterinaireId,
      createdByModel: "Veterinarian",
    });

    const photoUrl = `${req.protocol}://${req.get("host")}/uploads/posts/${newPost.photo}`;

    return res.status(201).json({
      message: "Post créé avec succès",
      post: {
        _id: newPost._id,
        photo: photoUrl,
        description: newPost.description,
        createdAt: newPost.createdAt,
        updatedAt: newPost.updatedAt,
      },
    });
  } catch (error: any) {
    const filePath = path.join(__dirname, "..", "services", "uploads", "posts", req.file.filename);
    try { await unlinkAsync(filePath); } catch {}

    return res.status(500).json({
      message: "Erreur lors de la création du post",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

// 📌 Mettre à jour un post
export const updatePost = async (req: Request, res: Response): Promise<Response> => {
  const { veterinaireId, id: postId } = req.params;

  if (!veterinaireId || !postId) {
    return res.status(400).json({ message: "veterinaireId et postId sont requis." });
  }

  try {
    const post = await Post.findOne({ _id: postId, veterinaireId });
    if (!post) {
      return res.status(404).json({ message: "Post non trouvé ou accès non autorisé." });
    }

    let oldImage: string | null = null;
    if (req.file) {
      oldImage = post.photo;
      post.photo = req.file.filename;
    }

    if (typeof req.body.description === 'string') {
      post.description = req.body.description;
    }

    const updatedPost = await post.save();

    if (oldImage) {
      const filePath = path.join(__dirname, "..", "services", "uploads", "posts", oldImage);
      if (fs.existsSync(filePath)) {
        try { await unlinkAsync(filePath); } catch (e) { console.error(e); }
      }
    }

    const photoUrl = `${req.protocol}://${req.get("host")}/uploads/posts/${updatedPost.photo}`;
    return res.status(200).json({
      message: "Post mis à jour avec succès",
      post: {
        _id: updatedPost._id,
        photo: photoUrl,
        description: updatedPost.description,
        updatedAt: updatedPost.updatedAt,
      },
    });
  } catch (error: any) {
    console.error("Erreur dans updatePost:", error);
    return res.status(500).json({
      message: "Erreur lors de la mise à jour du post",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

// 📌 Supprimer un post
export const deletePost = async (req: Request, res: Response): Promise<Response> => {
  const { veterinaireId, id: postId } = req.params;

  if (!veterinaireId || !postId) {
    return res.status(400).json({ message: "veterinaireId et postId sont requis." });
  }

  try {
    const post = await Post.findOneAndDelete({ _id: postId, veterinaireId });
    if (!post) {
      return res.status(404).json({ message: "Post non trouvé ou accès non autorisé." });
    }

    const filePath = path.join(__dirname, "..", "services", "uploads", "posts", post.photo);
    try { await unlinkAsync(filePath); } catch {}

    return res.status(200).json({ message: "Post supprimé avec succès" });
  } catch (error: any) {
    return res.status(500).json({ 
      message: "Erreur lors de la suppression du post", 
      error: process.env.NODE_ENV === 'development' ? error.message : undefined 
    });
  }
};

// 📌 Récupérer tous les posts d'un vétérinaire
export const getVeterinairePosts = async (req: Request, res: Response): Promise<Response> => {
  const { veterinaireId } = req.params;

  if (!veterinaireId) {
    return res.status(400).json({ message: "Le champ veterinaireId est requis." });
  }

  try {
    const posts = await Post.find({ veterinaireId })
      .sort({ createdAt: -1 })
      .populate([
        {
          path: 'createdBy',
          model: 'User',
          select: 'firstName lastName profilePicture'
        },
        {
          path: 'reactions.userId',
          model: 'User',
          select: 'firstName lastName profilePicture'
        }
      ]);

    const host = `${req.protocol}://${req.get('host')}`;
    const response = posts.map(formatPostResponse(host));

    return res.status(200).json(response);
  } catch (err: any) {
    console.error("Erreur getVeterinairePosts:", err);
    return res.status(500).json({
      message: "Erreur lors de la récupération des posts",
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
};

// 📌 Récupérer tous les posts
export const getAllPosts = async (req: Request, res: Response): Promise<Response> => {
  try {
    const posts = await Post.find()
      .sort({ createdAt: -1 })
      .populate([
        {
          path: 'veterinaireId',
          model: 'User',
          select: 'firstName lastName profilePicture'
        },
        {
          path: 'reactions.userId',
          model: 'User',
          select: 'firstName lastName profilePicture'
        }
      ]);

    const host = `${req.protocol}://${req.get('host')}`;
    const response = posts.map(formatPostResponse(host));

    return res.status(200).json(response);
  } catch (err: any) {
    console.error("Erreur getAllPosts:", err);
    return res.status(500).json({
      message: "Erreur lors de la récupération des posts",
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
};

// 📌 Gestion des réactions
export const addReaction = async (req: Request, res: Response): Promise<Response> => {
  const { postId } = req.params;
  const { userId, type } = req.body;
  const validReactionTypes = ["j'aime", "j'adore", "triste", "j'admire"];

  if (!userId || !type) {
    return res.status(400).json({ message: "userId et type sont requis." });
  }

  if (!validReactionTypes.includes(type)) {
    return res.status(400).json({ 
      message: "Type de réaction invalide.",
      validTypes: validReactionTypes
    });
  }

  try {
    const user = await User.findById(userId).select('firstName lastName profilePicture');
    if (!user) {
      return res.status(404).json({ message: "Utilisateur non trouvé." });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ message: "Post non trouvé." });
    }

    const reactionIndex = post.reactions.findIndex(r => r.userId.toString() === userId);
    const userDetails = {
      firstName: user.firstName,
      lastName: user.lastName,
      profilePicture: user.profilePicture
    };

    if (reactionIndex !== -1) {
      post.reactions[reactionIndex] = { userId, type, userDetails };
    } else {
      post.reactions.push({ userId, type, userDetails });
    }

    await post.save();
    return res.status(200).json({ 
      message: "Réaction enregistrée",
      reaction: { type, user: userDetails }
    });
  } catch (error: any) {
    console.error("Erreur addReaction:", error);
    return res.status(500).json({ 
      message: "Erreur lors de l'ajout de la réaction",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

export const deleteReaction = async (req: Request, res: Response): Promise<Response> => {
  const { postId } = req.params;
  const { userId } = req.body;

  if (!userId) {
    return res.status(400).json({ message: "userId est requis." });
  }

  try {
    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ message: "Post non trouvé." });
    }

    const initialLength = post.reactions.length;
    post.reactions = post.reactions.filter(r => r.userId.toString() !== userId);

    if (post.reactions.length === initialLength) {
      return res.status(404).json({ message: "Réaction non trouvée." });
    }

    await post.save();
    return res.status(200).json({ message: "Réaction supprimée" });
  } catch (error: any) {
    console.error("Erreur deleteReaction:", error);
    return res.status(500).json({ 
      message: "Erreur lors de la suppression de la réaction",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

export const getReactionsSummary = async (req: Request, res: Response): Promise<Response> => {
  const { postId } = req.params;

  try {
    const post = await Post.findById(postId)
      .populate({
        path: 'reactions.userId',
        model: 'User',
        select: 'firstName lastName profilePicture'
      });

    if (!post) {
      return res.status(404).json({ message: "Post non trouvé." });
    }

    const counts = {
      total: post.reactions.length,
      "j'aime": 0,
      "j'adore": 0,
      triste: 0,
      "j'admire": 0
    };

    const userReactions = post.reactions.map(reaction => {
      counts[reaction.type as keyof typeof counts]++;
      
      return {
        type: reaction.type,
        user: {
          _id: reaction.userId._id,
          firstName: (reaction.userId as any).firstName,
          lastName: (reaction.userId as any).lastName,
          profilePicture: (reaction.userId as any).profilePicture
        }
      };
    });

    return res.status(200).json({
      counts,
      userReactions
    });
  } catch (error: any) {
    console.error("Erreur getReactionsSummary:", error);
    return res.status(500).json({ 
      message: "Erreur lors de la récupération des réactions",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Helper function to format post response
const formatPostResponse = (host: string) => (post: any): IPostResponse => {
  const counts = {
    total: post.reactions.length,
    "j'aime": 0,
    "j'adore": 0,
    triste: 0,
    "j'admire": 0
  };

  const userReactions = post.reactions.map((reaction: any) => {
    counts[reaction.type as keyof typeof counts]++;
    
    return {
      type: reaction.type,
      user: {
        _id: reaction.userId._id,
        firstName: reaction.userId.firstName,
        lastName: reaction.userId.lastName,
        profilePicture: reaction.userId.profilePicture
      }
    };
  });

  return {
    _id: post._id,
    photo: `${host}/uploads/posts/${post.photo}`,
    description: post.description,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
    veterinaire: {
      _id: post.veterinaireId?._id || post.createdBy._id,
      firstName: post.veterinaireId?.firstName || post.createdBy.firstName,
      lastName: post.veterinaireId?.lastName || post.createdBy.lastName,
      profilePicture: post.veterinaireId?.profilePicture || post.createdBy.profilePicture
    },
    reactions: {
      counts,
      userReactions
    }
  };
};