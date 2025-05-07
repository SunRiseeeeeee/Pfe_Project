// src/services/serviceMulterConfig.ts
import multer from 'multer';
import path from 'path';
import fs from 'fs';

// ← ici on part de src/services
const servicesUploadDir = path.join(__dirname, 'uploads', 'services');

// créer le dossier si besoin
if (!fs.existsSync(servicesUploadDir)) {
  fs.mkdirSync(servicesUploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, servicesUploadDir);
  },
  filename: (_req, file, cb) => {
    const unique = `service-${Date.now()}-${Math.floor(Math.random()*100000)}${path.extname(file.originalname)}`;
    cb(null, unique);
  }
});

export const serviceUpload = multer({
  storage,
  fileFilter: (_req, file, cb) => {
    file.mimetype.startsWith('image/') 
      ? cb(null, true) 
      : cb(new Error('Seuls les fichiers image sont autorisés'));
  },
  limits: { fileSize: 5 * 1024 * 1024 },
}).single('image');
