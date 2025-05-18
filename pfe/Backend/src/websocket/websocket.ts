import WebSocket, { WebSocketServer } from 'ws';
import mongoose, { Types } from 'mongoose';
import Chat from '../models/Chat';
import Message, { MessageType } from '../models/Message';
import User from '../models/User';

const clients = new Map<string, WebSocket>();
const wss = new WebSocketServer({ port: 3001 });

/**
 * Vérifie si un ID est un ObjectId valide de MongoDB.
 */
const isValidObjectId = (id: string) => mongoose.Types.ObjectId.isValid(id);

/**
 * Crée un chat automatiquement s'il n'existe pas déjà.
 */
const getOrCreateChat = async (
  senderId: string,
  veterinaireId: string
): Promise<Types.ObjectId> => {
  if (!isValidObjectId(senderId) || !isValidObjectId(veterinaireId)) {
    throw new Error('Invalid user IDs');
  }

  const veterinaire = await User.findById(veterinaireId);
  if (!veterinaire) throw new Error('Vétérinaire introuvable');

  const secretaires = await User.find({ role: 'SECRETAIRE', veterinaireId }).select('_id');

  const participants = [
    new Types.ObjectId(senderId),
    new Types.ObjectId(veterinaireId),
    ...secretaires.map((s) => s._id),
  ].sort();

  const existingChat = await Chat.findOne({
    participants: { $all: participants, $size: participants.length },
  });

  if (existingChat) {
    console.log(`✅ Chat existant trouvé : ${existingChat._id}`);
    return existingChat.id;
  }

  const newChat = await Chat.create({
    participants,
    unreadCount: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  console.log(`🆕 Nouveau chat créé : ${newChat._id}`);
  return newChat.id;
};

/**
 * Écoute des connexions WebSocket.
 */
wss.on('connection', (ws: WebSocket) => {
  console.log('Client connecté.');

  ws.on('message', async (message: string) => {
    console.log(`Message reçu : ${message}`);

    try {
      const { senderId, veterinaireId, content } = JSON.parse(message);

      // Enregistrement du client
      if (senderId) {
        clients.set(senderId, ws);
        ws.send(JSON.stringify({
          status: 'success',
          message: `Client ${senderId} enregistré.`,
        }));
      }

      if (!senderId || !veterinaireId || !content) {
        throw new Error('senderId, veterinaireId et content sont requis.');
      }

      // Créer le chat s'il n'existe pas encore
      const chatId = await getOrCreateChat(senderId, veterinaireId);

      // Sauvegarde du message dans MongoDB
      const newMessage = await Message.create({
        chatId,
        sender: new Types.ObjectId(senderId),
        type: MessageType.TEXT,
        content,
        readBy: [],
      });

      console.log(`💾 Message sauvegardé : ${newMessage._id}`);

      // Envoi du message au vétérinaire s'il est connecté
      const recipientSocket = clients.get(veterinaireId);

      if (recipientSocket && recipientSocket.readyState === WebSocket.OPEN) {
        recipientSocket.send(JSON.stringify({
          senderId,
          content,
          timestamp: Date.now(),
        }));

        console.log(`📩 Message envoyé au vétérinaire ${veterinaireId}`);
      } else {
        console.log(`⚠️ Vétérinaire ${veterinaireId} non connecté.`);
      }

      ws.send(JSON.stringify({
        status: 'success',
        message: `Message envoyé à ${veterinaireId}`,
      }));

    } catch (e) {
      console.error('Erreur de traitement:', (e as Error).message);
      ws.send(JSON.stringify({
        status: 'error',
        message: (e as Error).message,
      }));
    }
  });

  ws.on('close', () => {
    console.log('Client déconnecté.');
  });
});

console.log('WebSocket en écoute sur ws://localhost:3001/');
export { wss, clients };
