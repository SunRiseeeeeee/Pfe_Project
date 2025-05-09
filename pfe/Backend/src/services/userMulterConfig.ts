import multer from 'multer';
import path from 'path';
import fs from 'fs';

// Définir le répertoire pour les images des utilisateurs
const userUploadDir = path.join(__dirname, 'uploads', 'users');

// Créer le répertoire si il n'existe pas
if (!fs.existsSync(userUploadDir)) {
  fs.mkdirSync(userUploadDir, { recursive: true });
}

// Définir la configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, userUploadDir); // Répertoire où le fichier sera stocké
  },
  filename: (req, file, cb) => {
    // Générer un nom de fichier unique
    const uniqueName = `profile-${Date.now()}-${Math.floor(Math.random() * 10000)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

// Configuration de multer pour accepter un fichier unique avec le champ 'profilePicture'
const userUpload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true); // Vérification que le fichier est bien une image
    else cb(new Error('Seules les images sont autorisées'));
  },
  limits: { fileSize: 5 * 1024 * 1024 } // Limite de taille à 5 Mo
}).single('profilePicture'); // Le nom du champ dans le formulaire

export { userUpload };
