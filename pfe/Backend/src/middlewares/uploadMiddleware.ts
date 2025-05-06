import multer from 'multer';
import path from 'path';
import fs from 'fs';

// Chemin vers le dossier d'upload
const uploadDir = path.join(__dirname, '..', 'services', 'uploads');

// Créer le dossier s'il n'existe pas
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const filename = `image-${Date.now()}-${Math.floor(Math.random() * 100000)}${path.extname(file.originalname)}`;
    cb(null, filename);
  },
});

// Filtrer les types de fichiers
const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Seuls les fichiers image sont autorisés'));
  }
};

// Configuration de multer
const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 Mo max
}).single('image'); // 'image' est le nom du champ dans le formulaire

export { upload };
