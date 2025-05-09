import multer from 'multer';
import path from 'path';
import fs from 'fs';

// 📌 Chemin vers le dossier d'upload des posts
const postsUploadDir = path.join(__dirname, '..', 'services', 'uploads', 'posts');

// 📌 Créer le dossier s'il n'existe pas
if (!fs.existsSync(postsUploadDir)) {
  fs.mkdirSync(postsUploadDir, { recursive: true });
}

// 📌 Configuration de stockage pour les posts
const postsStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, postsUploadDir);
  },
  filename: (req, file, cb) => {
    const filename = `post-${Date.now()}-${Math.floor(Math.random() * 100000)}${path.extname(file.originalname)}`;
    cb(null, filename);
  },
});

// 📌 Filtrer les types de fichiers (images uniquement)
const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Seuls les fichiers image sont autorisés'));
  }
};

// 📌 Configuration de multer pour les posts
const postUpload = multer({
  storage: postsStorage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 Mo max
}).single('image'); // Le champ de formulaire s'appelle 'image'

export { postUpload };
