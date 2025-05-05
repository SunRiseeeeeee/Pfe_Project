import multer from 'multer';
import path from 'path';
import fs from 'fs';

// Créer le dossier s'il n'existe pas
const uploadDir = path.join(__dirname, 'uploads', 'animals','users');
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

// Configuration de multer pour accepter un fichier unique avec le champ 'image'
const upload = multer({ storage }).single('image'); // 'image' correspond au champ du formulaire
export { upload };