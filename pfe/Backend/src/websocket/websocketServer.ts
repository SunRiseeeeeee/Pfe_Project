import WebSocket, { WebSocketServer } from 'ws';
import mongoose, { Types } from 'mongoose';
import Chat from '../models/Chat';
import Message, { MessageType } from '../models/Message';
import User from '../models/User';

// Map pour stocker les connexions actives : userId -> WebSocket
const clients = new Map<string, WebSocket>();

// Serveur WebSocket sur le port 3001
const wss = new WebSocketServer({ port: 3001 });

// Vérifie si une chaîne est un ObjectId MongoDB valide
const isValidObjectId = (id: string): boolean => mongoose.Types.ObjectId.isValid(id);

/**
 * Récupère ou crée un chat avec les participants : sender, vétérinaire et secrétaires associés.
 */
async function getOrCreateChat(senderId: string, veterinaireId: string): Promise<Types.ObjectId> {
  if (!isValidObjectId(senderId) || !isValidObjectId(veterinaireId)) {
    throw new Error('IDs utilisateur invalides');
  }

  const veterinaire = await User.findById(veterinaireId);
  if (!veterinaire) throw new Error('Vétérinaire introuvable');

  // Récupérer les secrétaires liés au vétérinaire
  const secretaires = await User.find({ role: 'SECRETAIRE', veterinaireId }).select('_id');

  // Construire la liste des participants (triée)
  const participants = [
    new Types.ObjectId(senderId),
    new Types.ObjectId(veterinaireId),
    ...secretaires.map((s) => s._id),
  ].sort((a, b) => a.toString().localeCompare(b.toString()));

  // Chercher un chat existant avec ces participants exacts
  const existingChat = await Chat.findOne({
    participants: { $all: participants, $size: participants.length },
  });

  if (existingChat) {
    console.log(`✅ Chat existant trouvé : ${existingChat._id}`);
    return existingChat.id;
  }

  // Créer un nouveau chat
  const newChat = await Chat.create({
    participants,
    unreadCount: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  console.log(`🆕 Nouveau chat créé : ${newChat._id}`);
  return newChat.id;
}

/**
 * Marque tous les messages non lus d'un chat comme lus par un utilisateur.
 */
async function markMessagesAsRead(chatId: string, userId: string): Promise<void> {
  if (!isValidObjectId(chatId) || !isValidObjectId(userId)) {
    throw new Error('chatId ou userId invalide');
  }

  const result = await Message.updateMany(
    {
      chatId: new Types.ObjectId(chatId),
      readBy: { $ne: new Types.ObjectId(userId) },
    },
    {
      $push: { readBy: new Types.ObjectId(userId) },
    }
  );

  console.log(`✔️ Messages marqués comme lus pour user ${userId} dans chat ${chatId} : ${result.modifiedCount}`);
}

/**
 * Récupère les conversations d'un utilisateur avec le nombre de messages non lus.
 */
async function getConversationsForUser(userId: string) {
  if (!isValidObjectId(userId)) throw new Error('userId invalide');

  const userObjectId = new Types.ObjectId(userId);

  // Trouver les chats où l'utilisateur est participant
  const chats = await Chat.find({ participants: userObjectId }).sort({ updatedAt: -1 });

  // Pour chaque chat, compter les messages non lus par l'utilisateur
  const conversations = await Promise.all(
    chats.map(async (chat) => {
      const unreadCount = await Message.countDocuments({
        chatId: chat._id,
        readBy: { $ne: userObjectId },
        sender: { $ne: userObjectId },
      });

      return {
        chatId: chat._id,
        participants: chat.participants,
        unreadCount,
        updatedAt: chat.updatedAt,
      };
    })
  );

  return conversations;
}

/**
 * Récupère tous les messages d'un chat, triés par date.
 */
async function getMessagesForChat(chatId: string) {
  if (!isValidObjectId(chatId)) throw new Error('chatId invalide');

  const messages = await Message.find({ chatId: new Types.ObjectId(chatId) })
    .sort({ createdAt: 1 })
    .populate('sender', 'firstName lastName');

  return messages;
}

// Gestion des connexions WebSocket
wss.on('connection', (ws: WebSocket) => {
  console.log('⚡ Client connecté.');

ws.on('message', async (rawMessage: string) => {
  console.log(`💬 Message reçu : ${rawMessage}`);

  try {
    const data = JSON.parse(rawMessage);

    // Enregistrement client
    if (data.role && (data.senderId || data.veterinaireId)) {
      const id = data.senderId || data.veterinaireId;
      clients.set(id, ws);
      console.log(`${data.role} ${id} connecté via WebSocket.`);
      ws.send(JSON.stringify({
        status: 'success',
        message: `${data.role} ${id} enregistré.`,
      }));
      return;
    }

    if (!data.type) {
      throw new Error('Type de message manquant');
    }

    switch (data.type) {
      case 'MARK_AS_READ': {
        const { chatId, userId } = data;
        if (!chatId || !userId) throw new Error('chatId et userId sont requis pour MARK_AS_READ');
        if (!isValidObjectId(chatId) || !isValidObjectId(userId)) throw new Error('chatId ou userId invalide');

        const updateResult = await Message.updateMany(
          {
            chatId: new Types.ObjectId(chatId),
            readBy: { $ne: new Types.ObjectId(userId) },
            sender: { $ne: new Types.ObjectId(userId) },
          },
          { $push: { readBy: new Types.ObjectId(userId) } }
        );

        console.log(`✅ ${updateResult.modifiedCount} messages marqués comme lus par ${userId} dans le chat ${chatId}`);

        ws.send(JSON.stringify({
          status: 'success',
          message: `Messages marqués comme lus : ${updateResult.modifiedCount}`,
          modifiedCount: updateResult.modifiedCount,
        }));
        break;
      }

      case 'GET_CONVERSATIONS': {
        const { userId } = data;
        if (!userId) throw new Error('userId est requis pour GET_CONVERSATIONS');
        if (!isValidObjectId(userId)) throw new Error('userId invalide');

        const chats = await Chat.find({ participants: new Types.ObjectId(userId) })
          .sort({ updatedAt: -1 })
          .lean();

        const conversations = await Promise.all(chats.map(async (chat) => {
          const participants = await User.find({ _id: { $in: chat.participants } })
            .select('firstName lastName role')
            .lean();

          const lastMessage = await Message.findOne({ chatId: chat._id })
            .sort({ createdAt: -1 })
            .select('content sender createdAt')
            .lean();

          const unreadCount = await Message.countDocuments({
            chatId: chat._id,
            sender: { $ne: new Types.ObjectId(userId) },
            readBy: { $ne: new Types.ObjectId(userId) },
          });

          return {
            chatId: chat._id,
            participants,
            lastMessage,
            updatedAt: chat.updatedAt,
            unreadCount,
          };
        }));

        ws.send(JSON.stringify({
          status: 'success',
          type: 'CONVERSATIONS_LIST',
          conversations,
        }));
        break;
      }

      case 'GET_MESSAGES': {
        const { chatId } = data;
        if (!chatId) throw new Error('chatId est requis pour GET_MESSAGES');
        if (!isValidObjectId(chatId)) throw new Error('chatId invalide');

        const messages = await Message.find({ chatId: new Types.ObjectId(chatId) })
          .sort({ createdAt: 1 })
          .populate('sender', 'firstName lastName')
          .lean();

        ws.send(JSON.stringify({
          status: 'success',
          type: 'MESSAGES_LIST',
          chatId,
          messages,
        }));
        break;
      }

      case 'SEND_MESSAGE': {
        const { senderId, veterinaireId, content } = data;
        if (!senderId || !veterinaireId || !content) {
          throw new Error('senderId, veterinaireId et content sont requis pour envoyer un message');
        }

        const chatId = await getOrCreateChat(senderId, veterinaireId);

        const newMessage = await Message.create({
          chatId,
          sender: new Types.ObjectId(senderId),
          type: MessageType.TEXT,
          content,
          readBy: [],
          createdAt: new Date(),
          updatedAt: new Date(),
        });

        console.log(`💾 Message sauvegardé : ${newMessage._id}`);

        const sender = await User.findById(senderId).select('firstName lastName');
        if (!sender) throw new Error('Expéditeur introuvable');
        const senderName = `${sender.firstName} ${sender.lastName}`;

        const chat = await Chat.findById(chatId).select('participants');
        if (!chat) throw new Error('Chat introuvable');

        for (const participantId of chat.participants) {
          const participantIdStr = participantId.toString();
          if (participantIdStr === senderId) continue;

          const recipientSocket = clients.get(participantIdStr);
          if (recipientSocket && recipientSocket.readyState === WebSocket.OPEN) {
            recipientSocket.send(JSON.stringify({
              type: 'NEW_MESSAGE',
              chatId,
              senderId,
              senderName,
              content,
              timestamp: Date.now(),
              notification: `${senderName} vous a envoyé un message`,
            }));
            console.log(`🔔 Notification envoyée à ${participantIdStr}`);
          }
        }

        ws.send(JSON.stringify({
          status: 'success',
          message: `Message envoyé au chat ${chatId}`,
          chatId,
        }));
        break;
      }

      default:
        throw new Error(`Type de message inconnu : ${data.type}`);
    }

  } catch (error) {
    console.error('❌ Erreur lors du traitement du message:', (error as Error).message);
    ws.send(JSON.stringify({
      status: 'error',
      message: (error as Error).message,
    }));
  }
});


  // Nettoyer la connexion à la fermeture
  ws.on('close', () => {
    console.log('❌ Client déconnecté.');
    for (const [userId, socket] of clients.entries()) {
      if (socket === ws) {
        clients.delete(userId);
        console.log(`Socket pour l’utilisateur ${userId} supprimé.`);
        break;
      }
    }
  });
});

console.log('🌐 WebSocket en écoute sur ws://localhost:3001/');

export { wss, clients };
