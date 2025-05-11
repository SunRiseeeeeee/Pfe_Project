import multer, { MulterError } from 'multer';
import path from 'path';
import fs from 'fs/promises';
import os from 'os';

// 📌 Chemin vers le dossier d'upload des messages de chat
const chatsUploadDir = process.env.UPLOAD_DIR
  ? path.resolve(process.env.UPLOAD_DIR, 'chats')
  : path.resolve(__dirname, '..', 'services', 'uploads', 'chats');

// 📌 Créer le dossier s'il n'existe pas (asynchrone)
const ensureUploadDir = async (): Promise<void> => {
  try {
    await fs.mkdir(chatsUploadDir, { recursive: true });
  } catch (error) {
    console.error('Erreur lors de la création du dossier d’upload:', error);
    throw new Error('Impossible de configurer le dossier d’upload');
  }
};

// 📌 Vérifier le dossier au démarrage
ensureUploadDir().catch((error) => {
  console.error('Échec de l’initialisation du dossier d’upload:', error);
  console.warn('Les uploads seront désactivés jusqu’à ce que le dossier soit accessible.');
});

// 📌 Configuration de stockage pour les messages de chat
const chatsStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, chatsUploadDir);
  },
  filename: (req, file, cb) => {
    const filename = `chat-${Date.now()}-${Math.floor(Math.random() * 100000)}${path.extname(file.originalname)}`;
    cb(null, filename);
  },
});

// 📌 Filtrer les types de fichiers (images, vidéos, audio, fichiers spécifiques)
const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowedTypes = [
    /^image\//, // Toutes les images (jpeg, png, gif, etc.)
    /^video\/(mp4|webm)$/, // MP4, WebM
    /^audio\/(mpeg|wav|ogg)$/, // MP3, WAV, OGG
    'application/pdf', // PDF
    'text/plain', // TXT
    'application/msword', // DOC
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // DOCX
  ];

  const isAllowed = allowedTypes.some((type) =>
    typeof type === 'string' ? file.mimetype === type : type.test(file.mimetype)
  );

  if (isAllowed) {
    cb(null, true);
  } else {
    cb(new MulterError('LIMIT_UNEXPECTED_FILE', `Type de fichier non supporté: ${file.mimetype}`));
  }
};

// 📌 Configuration de multer pour les messages de chat
const chatUpload = multer({
  storage: chatsStorage,
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 Mo max pour permettre vidéos/audio
});

export { chatUpload };