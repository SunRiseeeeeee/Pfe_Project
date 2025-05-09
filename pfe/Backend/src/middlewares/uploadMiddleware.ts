import multer from 'multer';
import path from 'path';
import fs from 'fs';

// 📌 Dossiers d'upload
const uploadDirs: Record<string, string> = {
  users: path.join(__dirname, '..', 'services', 'uploads', 'users'),
  animals: path.join(__dirname, '..', 'services', 'uploads', 'animals'),
  services: path.join(__dirname, '..', 'services', 'uploads', 'services'),
  posts: path.join(__dirname, '..', 'services', 'uploads', 'posts'),
};

// 📌 Création des dossiers s'ils n'existent pas
Object.values(uploadDirs).forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// 📌 Générer le nom du fichier
const generateFilename = (prefix: string, originalname: string): string => {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 100000)}${path.extname(originalname)}`;
};

// 📌 Configuration du stockage dynamique
const storage = (folder: string) =>
  multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, folder);
    },
    filename: (req, file, cb) => {
      cb(null, generateFilename(path.basename(folder), file.originalname));
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

// 📌 Configuration de multer pour chaque type
const userUpload = multer({
  storage: storage(uploadDirs.users),
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
}).single('image');

const animalUpload = multer({
  storage: storage(uploadDirs.animals),
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
}).single('image');

const serviceUpload = multer({
  storage: storage(uploadDirs.services),
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
}).single('image');

const postUpload = multer({
  storage: storage(uploadDirs.posts),
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
}).single('photo'); // Le champ de formulaire s'appelle 'photo' pour les posts

// 📌 Export des configurations
export { userUpload, animalUpload, serviceUpload, postUpload };
