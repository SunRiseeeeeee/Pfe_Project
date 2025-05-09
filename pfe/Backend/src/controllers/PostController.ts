import { Request, Response } from "express";
import Post from "../models/Post";
import { postUpload } from "../services/PostMulterConfig";
import fs from "fs";
import path from "path";
import { promisify } from "util";

const unlinkAsync = promisify(fs.unlink);

// Interface pour typer correctement le modèle Post
interface IPost {
  _id: string;
  photo: string;
  description: string;
  veterinaireId: string;
  createdAt: Date;
  updatedAt: Date;  // Assurez-vous que ce champ est inclus dans le modèle Mongoose de Post
  save(): Promise<IPost>;
}

// 📌 Créer un post


export const createPost = async (req: Request, res: Response): Promise<Response> => {
    // 1️⃣ Vérifier l'image
    if (!req.file) {
      return res.status(400).json({ message: "L'image est requise." });
    }
  
    // 2️⃣ Extraire veterinaireId depuis les params et description depuis le body
    const { description } = req.body;
    const { veterinaireId } = req.params;
    if (!veterinaireId) {
      return res.status(400).json({ message: "Le champ veterinaireId est requis dans l'URL." });
    }
  
    try {
      // 3️⃣ Créer l'enregistrement (stockage du nom de fichier)
      const newPost = await Post.create({
        photo: req.file.filename,
        description,
        veterinaireId,
        createdBy: veterinaireId,
        createdByModel: "Veterinarian",
      });
  
      // 4️⃣ Construire l'URL publique
      const photoUrl = `${req.protocol}://${req.get("host")}/uploads/posts/${newPost.photo}`;
  
      // 5️⃣ Retourner la réponse
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
      // 6️⃣ Nettoyage en cas d'erreur
      const filePath = path.join(
        __dirname,
        "..",
        "services",
        "uploads",
        "posts",
        req.file.filename
      );
      try { await unlinkAsync(filePath); } catch {};
  
      return res.status(500).json({
        message: "Erreur lors de la création du post",
        error: process.env.NODE_ENV === "development" ? error.message : undefined,
      });
    }
  };
  
// 📌 Mettre à jour un post (par son créateur vétérinaire)
export const updatePost = async (req: Request, res: Response): Promise<Response> => {
    if (!req.params.veterinaireId) {
      return res.status(400).json({ message: "Le champ veterinaireId est requis dans l'URL." });
    }
    if (!req.params.id) {
      return res.status(400).json({ message: "L'ID du post est requis dans l'URL." });
    }
  
    const { veterinaireId, id: postId } = req.params;
  
    try {
      // Recherche du post par vétérinaire
      const post = await Post.findOne({ _id: postId, veterinaireId });
      if (!post) {
        return res.status(404).json({ message: "Post non trouvé ou accès non autorisé." });
      }
  
      // Gestion du nouveau fichier
      let oldImage: string | null = null;
      if (req.file) {
        oldImage = post.photo;
        post.photo = req.file.filename;
      }
  
      // Mise à jour de la description si existante
      if (typeof req.body.description === 'string') {
        post.description = req.body.description;
      }
  
      // Sauvegarde (timestamps gère updatedAt)
      const updatedPost = await post.save();
  
      // Suppression de l'ancienne image
      if (oldImage) {
        const filePath = path.join(
          __dirname,
          "..",
          "services",
          "uploads",
          "posts",
          oldImage
        );
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
      return res.status(400).json({ message: "veterinaireId et ID du post requis dans l'URL." });
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
      return res.status(500).json({ message: "Erreur lors de la suppression du post", error: process.env.NODE_ENV==='development'?error.message:undefined });
    }
  };
  
// 📌 Récupérer tous les posts d'un vétérinaire

export const getVeterinairePosts = async (req: Request, res: Response): Promise<Response> => {
    const { veterinaireId } = req.params;
    if (!veterinaireId) {
      return res.status(400).json({ message: "Le champ veterinaireId est requis dans l'URL." });
    }
    try {
      const posts = await Post.find({ veterinaireId })
        .sort({ createdAt: -1 })
        .populate({ path: 'veterinaireId', model: 'User', select: 'firstName lastName profilePicture' });
  
      const withData = posts.map(p => ({
        _id: p._id,
        photo: `${req.protocol}://${req.get("host")}/uploads/posts/${p.photo}`,
        description: p.description,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
        veterinaire: (p.veterinaireId as any),
      }));
  
      return res.status(200).json(withData);
    } catch (error: any) {
      return res.status(500).json({ message: "Erreur lors de la récupération des posts", error: process.env.NODE_ENV==='development'?error.message:undefined });
    }
  };
  
  // 📌 Récupérer tous les posts
  export const getAllPosts = async (_req: Request, res: Response): Promise<Response> => {
    try {
      const posts = await Post.find()
        .sort({ createdAt: -1 })
        .populate({ path: 'veterinaireId', model: 'User', select: 'firstName lastName profilePicture' });
  
      const host = _req.protocol + '://' + _req.get("host");
      const withData = posts.map(p => ({
        _id: p._id,
        photo: `${host}/uploads/posts/${p.photo}`,
        description: p.description,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
        veterinaire: (p.veterinaireId as any),
      }));
  
      return res.status(200).json(withData);
    } catch (error: any) {
      return res.status(500).json({ message: "Erreur lors de la récupération des posts", error: process.env.NODE_ENV==='development'?error.message:undefined });
    }
  };
  