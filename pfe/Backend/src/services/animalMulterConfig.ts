import multer from 'multer';
import path from 'path';
import fs from 'fs';

// Créer le dossier s'il n'existe pas
const uploadDir = path.join(__dirname, 'uploads', 'animals');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Définir le stockage des fichiers
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir); // Répertoire où le fichier sera stocké
  },
  filename: (req, file, cb) => {
    // Utilisation d'un nom de fichier unique
    const filename = `image-${Date.now()}-${Math.floor(Math.random() * 100000)}${path.extname(file.originalname)}`;
    cb(null, filename);
  },
});

// Filtrer les fichiers pour accepter uniquement les images
const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true); // Accepter le fichier
  } else {
    cb(null, false); // Ne pas accepter le fichier
  }
};

// Configuration de multer pour accepter un fichier unique avec le champ 'image' et une taille max de 5 Mo
const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // Limite à 5 Mo
}).single('image'); // 'image' correspond au champ du formulaire

export { upload };
