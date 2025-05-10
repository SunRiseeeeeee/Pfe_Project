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

// 📌 Filtrer les types de fichiers (images et vidéos uniquement)
const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowedTypes = ['image/', 'video/mp4', 'video/avi', 'video/mpeg', 'video/quicktime'];
  if (allowedTypes.some(type => file.mimetype.startsWith(type))) {
    cb(null, true);
  } else {
    cb(new Error('Seuls les fichiers image ou vidéo sont autorisés'));
  }
};

// 📌 Configuration de multer pour les posts
const postUpload = multer({
  storage: postsStorage,
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 Mo max pour permettre les vidéos
}).single('media'); // Le champ de formulaire s'appelle 'media'

export { postUpload };