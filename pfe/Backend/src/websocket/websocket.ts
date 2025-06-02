import WebSocket, { WebSocketServer } from 'ws';
import mongoose, { Types } from 'mongoose';
import Chat from '../models/Chat';
import Message, { MessageType } from '../models/Message';
import User from '../models/User';
import { UserRole } from '../models/User'; 

const clients = new Map<string, WebSocket>();
const wss = new WebSocketServer({ port: 3001 });

const isValidObjectId = (id: string): boolean => mongoose.Types.ObjectId.isValid(id);

const getOrCreateChat = async (
  senderId: string,
  veterinaireId: string
): Promise<Types.ObjectId> => {
  if (!isValidObjectId(senderId) || !isValidObjectId(veterinaireId)) {
    throw new Error('IDs utilisateurs invalides');
  }

  // Vérifier que l'expéditeur est un client
  const sender = await User.findById(senderId);
  if (!sender) throw new Error('Expéditeur introuvable');
  if (sender.role !== UserRole.CLIENT) {
    throw new Error('Seuls les clients peuvent initier une conversation');
  }

  // Vérifier que le destinataire est bien un vétérinaire
  const veterinaire = await User.findById(veterinaireId);
  if (!veterinaire) throw new Error('Vétérinaire introuvable');
  if (veterinaire.role !== UserRole.VETERINAIRE) {
    throw new Error('Le destinataire doit être un vétérinaire');
  }

  // Récupérer tous les secrétaires associés à ce vétérinaire
  const secretaires = await User.find({ 
    role: UserRole.SECRETAIRE, 
    veterinaireId: veterinaireId 
  }).select('_id').lean();

  // Créer le tableau des participants (client + vétérinaire + secrétaires)
  const participants = [
    new Types.ObjectId(senderId),
    new Types.ObjectId(veterinaireId),
    ...secretaires.map(s => s._id)
  ].sort();

  // Rechercher un chat existant avec exactement ces participants
  const existingChat = await Chat.findOne({
    participants: { 
      $all: participants,
      $size: participants.length 
    }
  }).exec();

  if (existingChat) {
    console.log(`✅ Chat existant trouvé : ${existingChat._id}`);
    return existingChat.id;
  }

  // Créer un nouveau chat si aucun existant
  const newChat = await Chat.create({
    participants,
    unreadCount: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  console.log(`🆕 Nouveau chat créé avec ${participants.length} participants: ${newChat._id}`);
  return newChat.id;
};

wss.on('connection', (ws: WebSocket) => {
  console.log('Client connecté.');

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

  if (!userId) {
    ws.send(JSON.stringify({ status: 'error', message: 'userId est requis' }));
    break;
  }

  // Interfaces locales pour typer correctement les données peuplées
  interface PopulatedParticipant {
    _id: string;
    firstName: string;
    lastName: string;
    profilePicture?: string;
  }

  interface PopulatedLastMessage {
    content: string;
    type: string;
    createdAt: Date;
  }

  interface PopulatedChat {
    _id: string;
    participants: PopulatedParticipant[];
    lastMessage?: PopulatedLastMessage;
    updatedAt: Date;
  }

  // Recherche des conversations
  const conversations = await Chat.find({ participants: userId })
    .populate({
      path: 'participants',
      select: 'firstName lastName profilePicture',
    })
    .populate({
      path: 'lastMessage',
      select: 'content type createdAt',
    })
    .sort({ updatedAt: -1 })
    .lean<PopulatedChat[]>(); // typage explicite pour éviter les erreurs TS

  // Formatage des données
  const formattedConversations = conversations.map(chat => {
    const otherParticipants = chat.participants.filter(p => p._id.toString() !== userId);

    return {
      chatId: chat._id,
      participants: otherParticipants.map(p => ({
        id: p._id,
        firstName: p.firstName,
        lastName: p.lastName,
        profilePicture: p.profilePicture,
      })),
      lastMessage: chat.lastMessage
        ? {
            content: chat.lastMessage.content,
            type: chat.lastMessage.type,
            createdAt: chat.lastMessage.createdAt,
          }
        : null,
      updatedAt: chat.updatedAt,
    };
  });

  // Envoi au client
  ws.send(
    JSON.stringify({
      type: 'CONVERSATIONS_LIST',
      conversations: formattedConversations,
    })
  );

  break;
}


case 'GET_MESSAGES': {
  const { chatId } = data;

  if (!chatId) {
    throw new Error('chatId est requis pour GET_MESSAGES');
  }

  if (!isValidObjectId(chatId)) {
    throw new Error('chatId invalide');
  }

  // Interface pour typage des messages peuplés
  interface PopulatedMessage {
    _id: string;
    chatId: string;
    sender: {
      _id: string;
      firstName: string;
      lastName: string;
      profilePicture?: string;
    };
    content: string;
    type: string;
    createdAt: Date;
    updatedAt: Date;
  }

  const messages = await Message.find({ chatId: new Types.ObjectId(chatId) })
    .sort({ createdAt: 1 })
    .populate({
      path: 'sender',
      select: 'firstName lastName profilePicture',
    })
    .lean<PopulatedMessage[]>(); // Typage explicite pour éviter les erreurs TS

  ws.send(JSON.stringify({
    status: 'success',
    type: 'MESSAGES_LIST',
    chatId,
    messages,
  }));

  break;
}

case 'SEND_MESSAGE': {
  const { senderId, veterinaireId, content, contentType } = data;

  // Vérifications de base
  if (!senderId || !veterinaireId || !content) {
    throw new Error('senderId, veterinaireId et content sont requis');
  }

  // Vérifier que le sender est bien un client
  const sender = await User.findById(senderId);
  if (!sender || sender.role !== UserRole.CLIENT) {
    throw new Error('Seuls les clients peuvent initier une conversation');
  }

  // Créer ou récupérer le chat (incluant automatiquement les secrétaires)
  const chatId = await getOrCreateChat(senderId, veterinaireId);

  // Créer le message
  const newMessage = await Message.create({
    chatId,
    sender: new Types.ObjectId(senderId),
    type: contentType || MessageType.TEXT,
    content,
    readBy: [new Types.ObjectId(senderId)], // Marquer comme lu par l'expéditeur
  });

  // Mettre à jour le chat avec le dernier message
  await Chat.findByIdAndUpdate(chatId, {
    lastMessage: newMessage._id,
    updatedAt: new Date(),
  });

  // Notifier tous les participants
  const chat = await Chat.findById(chatId).populate('participants');
  if (!chat) throw new Error('Chat introuvable');

  for (const participant of chat.participants) {
    const participantId = participant._id.toString();
    if (participantId === senderId) continue; // Ne pas notifier l'expéditeur

    const recipientSocket = clients.get(participantId);
    if (recipientSocket?.readyState === WebSocket.OPEN) {
      recipientSocket.send(JSON.stringify({
        type: 'NEW_MESSAGE',
        chatId,
        message: {
          _id: newMessage._id,
          content,
          type: contentType || MessageType.TEXT,
          sender: {
            _id: senderId,
            firstName: sender.firstName,
            lastName: sender.lastName,
            profilePicture: sender.profilePicture,
          },
          createdAt: newMessage.createdAt,
        },
        notification: `Nouveau message de ${sender.firstName} ${sender.lastName}`
      }));
    }
  }

  ws.send(JSON.stringify({
    status: 'success',
    message: 'Message envoyé avec succès',
    chatId,
    messageId: newMessage._id,
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



  ws.on('close', () => {
    console.log('Client déconnecté.');
    for (const [id, socket] of clients.entries()) {
      if (socket === ws) {
        clients.delete(id);
        console.log(`Socket pour l’utilisateur ${id} supprimé.`);
        break;
      }
    }
  });
});

console.log('WebSocket en écoute sur ws://localhost:3001/');

export { wss, clients };
