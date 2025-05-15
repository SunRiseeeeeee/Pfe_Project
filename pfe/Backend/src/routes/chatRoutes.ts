import express from 'express';
import {
  sendMessage,
  getConversations,
  getMessages,
  markMessagesAsRead,

} from '../controllers/chatController';
import { chatUpload } from '../middlewares/uploadMiddleware';

const router = express.Router();

// Envoi de message avec création automatique de chat si nécessaire
router.post('/messages', chatUpload.single('file'), sendMessage, );

// Marquer les messages comme lus
router.post('/messages/read', markMessagesAsRead);

// Obtenir les conversations d'un utilisateur
router.get('/conversations/:userId', getConversations);

// Obtenir les messages d'une conversation spécifique
router.get('/conversations/:chatId/messages/:userId', getMessages);

export default router;