import { Request, Response } from "express";
import Post from "../models/Post";
import User from "../models/User";
import { postUpload } from "../services/PostMulterConfig";
import fs from "fs";
import path from "path";
import { promisify } from "util";
import { Types } from "mongoose";
import { IComment, IReaction } from "../models/Post";
import multer from "multer";

const unlinkAsync = promisify(fs.unlink);

// Interface pour typer les réponses des posts
interface IPostResponse {
  _id: Types.ObjectId;
  media: string;
  mediaType: "image" | "video";
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
  comments: Array<{
    _id: Types.ObjectId;
    content: string;
    user: {
      _id: Types.ObjectId;
      firstName: string;
      lastName: string;
      profilePicture?: string;
    };
    reactions: IReaction[];
    createdAt: Date;
    updatedAt: Date;
  }>;
  commentCount: number;
}

// 📌 Middleware to handle Multer errors
export const handleMulterError = (err: any, req: Request, res: Response, next: Function) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({ message: "Champ inattendu. Utilisez le champ 'media' pour le fichier." });
    }
    return res.status(400).json({ message: `Erreur Multer: ${err.message}` });
  }
  next(err);
};

// 📌 Créer un post
export const createPost = async (req: Request, res: Response): Promise<Response> => {
  if (!req.file) {
    return res.status(400).json({ message: "Le média (image ou vidéo) est requis." });
  }

  const { description } = req.body;
  const { veterinaireId } = req.params;

  if (!veterinaireId) {
    return res.status(400).json({ message: "Le champ veterinaireId est requis." });
  }

  try {
    const mediaType = req.file.mimetype.startsWith('image/') ? 'image' : 'video';
    const newPost = await Post.create({
      media: req.file.filename,
      mediaType,
      description,
      veterinaireId,
      createdBy: veterinaireId,
      createdByModel: "Veterinarian",
    });

    const mediaUrl = `${req.protocol}://${req.get("host")}/uploads/posts/${newPost.media}`;

    return res.status(201).json({
      message: "Post créé avec succès",
      post: {
        _id: newPost._id,
        media: mediaUrl,
        mediaType: newPost.mediaType,
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

    let oldMedia: string | null = null;
    if (req.file) {
      oldMedia = post.media;
      post.media = req.file.filename;
      post.mediaType = req.file.mimetype.startsWith('image/') ? 'image' : 'video';
    }

    if (typeof req.body.description === 'string') {
      post.description = req.body.description;
    }

    const updatedPost = await post.save();

    if (oldMedia) {
      const filePath = path.join(__dirname, "..", "services", "uploads", "posts", oldMedia);
      if (fs.existsSync(filePath)) {
        try { await unlinkAsync(filePath); } catch (e) { console.error(e); }
      }
    }

    const mediaUrl = `${req.protocol}://${req.get("host")}/uploads/posts/${updatedPost.media}`;
    return res.status(200).json({
      message: "Post mis à jour avec succès",
      post: {
        _id: updatedPost._id,
        media: mediaUrl,
        mediaType: updatedPost.mediaType,
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

    const filePath = path.join(__dirname, "..", "services", "uploads", "posts", post.media);
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
  const page = parseInt(req.query.page as string) || 1;
  const limit = parseInt(req.query.limit as string) || 10;
  const commentsLimit = parseInt(req.query.commentsLimit as string) || 15;
  const skip = (page - 1) * limit;

  if (!veterinaireId) {
    return res.status(400).json({ message: "Le champ veterinaireId est requis." });
  }

  try {
    // Requête pour les posts avec pagination
    const posts = await Post.find({ veterinaireId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
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
        },
        {
          path: 'comments',
          options: {
            sort: { createdAt: -1 },
            limit: commentsLimit
          },
          populate: {
            path: 'userId',
            model: 'User',
            select: 'firstName lastName profilePicture'
          }
        }
      ]);

    // Requête pour le nombre total de posts
    const totalPosts = await Post.countDocuments({ veterinaireId });
    const totalPages = Math.ceil(totalPosts / limit);

    const host = `${req.protocol}://${req.get('host')}`;
    const formattedPosts = posts.map(formatPostResponse(host));

    return res.status(200).json({
      posts: formattedPosts,
      pagination: {
        currentPage: page,
        totalPages,
        totalPosts,
        limit,
        hasNextPage: page < totalPages,
        hasPreviousPage: page > 1,
        commentsLimit
      }
    });
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
    // Pagination des posts
    const postsPage = parseInt(req.query.postsPage as string) || 1;
    const postsLimit = parseInt(req.query.postsLimit as string) || 10;
    const postsSkip = (postsPage - 1) * postsLimit;

    // Pagination des commentaires
    const commentsLimit = parseInt(req.query.commentsLimit as string) || 15;

    const posts = await Post.find()
      .sort({ createdAt: -1 })
      .skip(postsSkip)
      .limit(postsLimit)
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
        },
        {
          path: 'comments',
          options: {
            sort: { createdAt: -1 },
            limit: commentsLimit
          },
          populate: {
            path: 'userId',
            model: 'User',
            select: 'firstName lastName profilePicture'
          }
        }
      ]);

    // Comptage total des posts
    const totalPosts = await Post.countDocuments();
    const totalPostsPages = Math.ceil(totalPosts / postsLimit);

    const host = `${req.protocol}://${req.get('host')}`;
    const formattedPosts = posts.map(formatPostResponse(host));

    return res.status(200).json({
      posts: formattedPosts,
      pagination: {
        posts: {
          currentPage: postsPage,
          totalPages: totalPostsPages,
          totalPosts,
          limit: postsLimit,
          hasNextPage: postsPage < totalPostsPages,
          hasPreviousPage: postsPage > 1
        },
        comments: {
          limit: commentsLimit
        }
      }
    });
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

  const formattedComments = post.comments.map((comment: any) => ({
    _id: comment._id,
    content: comment.content,
    user: {
      _id: comment.userId,
      firstName: comment.userDetails?.firstName || '',
      lastName: comment.userDetails?.lastName || '',
      profilePicture: comment.userDetails?.profilePicture
    },
    reactions: comment.reactions,
    createdAt: comment.createdAt,
    updatedAt: comment.updatedAt
  }));

  return {
    _id: post._id,
    media: `${host}/uploads/posts/${post.media}`,
    mediaType: post.mediaType,
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
    },
    comments: formattedComments,
    commentCount: post.comments.length
  };
};

// 📌 Ajouter un commentaire
export const addComment = async (req: Request, res: Response): Promise<Response> => {
  const { postId } = req.params;
  const { userId, content } = req.body;

  if (!userId || !content) {
    return res.status(400).json({ message: "userId et content sont requis." });
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

    const newComment: IComment = {
      userId: new Types.ObjectId(userId),
      content,
      userDetails: {
        firstName: user.firstName,
        lastName: user.lastName,
        profilePicture: user.profilePicture
      },
      reactions: [],
      createdAt: new Date(),
      updatedAt: new Date()
    };

    post.comments.push(newComment);
    await post.save();

    return res.status(201).json({ 
      message: "Commentaire ajouté avec succès", 
      comment: {
        ...newComment,
        _id: post.comments[post.comments.length - 1]._id!
      } 
    });
  } catch (error: any) {
    console.error("Erreur addComment:", error);
    return res.status(500).json({ 
      message: "Erreur lors de l'ajout du commentaire",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// 📌 Modifier un commentaire
export const updateComment = async (req: Request, res: Response): Promise<Response> => {
  const { postId, commentId } = req.params;
  const { content } = req.body;

  if (!content) {
    return res.status(400).json({ message: "Le contenu du commentaire est requis." });
  }

  try {
    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ message: "Post non trouvé." });
    }

    const comment = post.comments.find(c => c._id!.toString() === commentId);
    if (!comment) {
      return res.status(404).json({ message: "Commentaire non trouvé." });
    }

    comment.content = content;
    comment.updatedAt = new Date();
    await post.save();

    return res.status(200).json({ 
      message: "Commentaire modifié avec succès", 
      comment: {
        ...comment,
        _id: comment._id!,
        user: {
          _id: comment.userId,
          firstName: comment.userDetails?.firstName || '',
          lastName: comment.userDetails?.lastName || '',
          profilePicture: comment.userDetails?.profilePicture
        }
      }
    });
  } catch (error: any) {
    console.error("Erreur updateComment:", error);
    return res.status(500).json({ 
      message: "Erreur lors de la modification du commentaire",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// 📌 Supprimer un commentaire
export const deleteComment = async (req: Request, res: Response): Promise<Response> => {
  const { postId, commentId } = req.params;

  try {
    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ message: "Post non trouvé." });
    }

    const commentIndex = post.comments.findIndex(c => c._id!.toString() === commentId);
    if (commentIndex === -1) {
      return res.status(404).json({ message: "Commentaire non trouvé." });
    }

    post.comments.splice(commentIndex, 1);
    await post.save();

    return res.status(200).json({ message: "Commentaire supprimé avec succès" });
  } catch (error: any) {
    console.error("Erreur deleteComment:", error);
    return res.status(500).json({ 
      message: "Erreur lors de la suppression du commentaire",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};