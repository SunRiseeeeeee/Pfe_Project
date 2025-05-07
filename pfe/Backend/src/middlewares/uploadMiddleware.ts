import multer from 'multer';
import path from 'path';
import fs from 'fs';

// 📌 Chemin vers le dossier d'upload des utilisateurs
const usersUploadDir = path.join(__dirname, '..', 'services', 'uploads', 'users');
// 📌 Chemin vers le dossier d'upload des animaux
const animalsUploadDir = path.join(__dirname, '..', 'services', 'uploads', 'animals');

// 📌 Créer les dossiers s'ils n'existent pas
if (!fs.existsSync(usersUploadDir)) {
  fs.mkdirSync(usersUploadDir, { recursive: true });
}
if (!fs.existsSync(animalsUploadDir)) {
  fs.mkdirSync(animalsUploadDir, { recursive: true });
}

// 📌 Configuration du stockage pour les utilisateurs
const usersStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, usersUploadDir);
  },
  filename: (req, file, cb) => {
    const filename = `user-${Date.now()}-${Math.floor(Math.random() * 100000)}${path.extname(file.originalname)}`;
    cb(null, filename);
  },
});

// 📌 Configuration du stockage pour les animaux
const animalsStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, animalsUploadDir);
  },
  filename: (req, file, cb) => {
    const filename = `animal-${Date.now()}-${Math.floor(Math.random() * 100000)}${path.extname(file.originalname)}`;
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

// 📌 Configuration de multer pour les utilisateurs
const userUpload = multer({
  storage: usersStorage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 Mo max
}).single('image'); // Le champ de formulaire s'appelle 'image'

// 📌 Configuration de multer pour les animaux
const animalUpload = multer({
  storage: animalsStorage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 Mo max
}).single('image'); // Le champ de formulaire s'appelle 'image'

export { userUpload, animalUpload };
