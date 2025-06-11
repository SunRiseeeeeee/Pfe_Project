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
  initiatorId: string,
  veterinaireId: string,
  clientId?: string
): Promise<Types.ObjectId> => {
  if (!isValidObjectId(initiatorId) || !isValidObjectId(veterinaireId)) {
    throw new Error('IDs invalides');
  }

  const initiator = await User.findById(initiatorId);
  if (!initiator) throw new Error('Utilisateur initiateur introuvable');

  const veterinaire = await User.findById(veterinaireId);
  if (!veterinaire || veterinaire.role !== UserRole.VETERINAIRE) {
    throw new Error('Vétérinaire introuvable ou invalide');
  }

  let finalClientId: string;

  if (initiator.role === UserRole.CLIENT) {
    finalClientId = initiatorId;
  } else {
    if (!clientId || !isValidObjectId(clientId)) {
      throw new Error('clientId requis pour un vétérinaire ou une secrétaire');
    }

    const client = await User.findById(clientId);
    if (!client || client.role !== UserRole.CLIENT) {
      throw new Error('clientId invalide ou utilisateur non client');
    }

    if (initiator.role === UserRole.SECRETAIRE && initiator.veterinaireId?.toString() !== veterinaireId) {
      throw new Error('Secrétaire non autorisé pour ce vétérinaire');
    }

    if (initiator.role === UserRole.VETERINAIRE && initiator._id.toString() !== veterinaireId) {
      throw new Error('Vétérinaire non autorisé');
    }

    finalClientId = clientId;
  }

  // Retrieve secretaries associated with the veterinarian
  const secretaires = await User.find({
    role: UserRole.SECRETAIRE,
    veterinaireId: veterinaireId,
  }).select('_id firstName lastName').lean();

  const participants = [
    new Types.ObjectId(finalClientId),
    new Types.ObjectId(veterinaireId),
    ...secretaires.map(s => s._id),
  ].sort();

  // Log participants for debugging
  console.log(`Participants for chat: ${participants.length}`);
  for (const participantId of participants) {
    const user = await User.findById(participantId).select('firstName lastName role');
    console.log(`- ${user?.firstName} ${user?.lastName} (${user?.role}, ID: ${participantId})`);
  }

  const existingChat = await Chat.findOne({
    participants: {
      $all: participants,
      $size: participants.length,
    },
  }).exec();

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
          const { userId, searchTerm } = data;

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
            role: UserRole;
          }

          interface PopulatedLastMessage {
            content: string;
            type: string;
            createdAt: Date;
            sender: {
              _id: string;
              firstName: string;
              lastName: string;
              profilePicture?: string;
              role: UserRole;
            };
          }

          interface PopulatedChat {
            _id: string;
            participants: PopulatedParticipant[];
            lastMessage?: PopulatedLastMessage;
            updatedAt: Date;
          }

          // Base query - get all chats for this user
          let query = Chat.find({ participants: userId });

          // Recherche des conversations avec populate
          let conversations = await query
            .populate({
              path: 'participants',
              select: 'firstName lastName profilePicture role',
            })
            .populate({
              path: 'lastMessage',
              select: 'content type createdAt',
              populate: {
                path: 'sender',
                select: 'firstName lastName profilePicture role',
              },
            })
            .sort({ updatedAt: -1 })
            .lean<PopulatedChat[]>();

          // Si un terme de recherche est fourni, filtrer les conversations
          if (searchTerm) {
            const currentUser = await User.findById(userId);
            if (!currentUser) {
              ws.send(JSON.stringify({ status: 'error', message: 'Utilisateur introuvable' }));
              break;
            }

            const searchTermLower = searchTerm.toLowerCase();

            conversations = conversations.filter(chat => {
              // Trouver les autres participants (exclure l'utilisateur courant)
              const otherParticipants = chat.participants.filter(
                p => p._id.toString() !== userId
              );

              // Pour chaque participant, vérifier si son nom correspond au terme de recherche
              return otherParticipants.some(participant => {
                // Si l'utilisateur courant est un client, on ne cherche que parmi les vétérinaires/secrétaires
                if (currentUser.role === UserRole.CLIENT) {
                  if (participant.role !== UserRole.VETERINAIRE && 
                      participant.role !== UserRole.SECRETAIRE) {
                    return false;
                  }
                }
                // Si l'utilisateur courant est un vétérinaire/secrétaire, on ne cherche que parmi les clients
                else {
                  if (participant.role !== UserRole.CLIENT) {
                    return false;
                  }
                }

                // Vérifier la correspondance avec le terme de recherche
                return (
                  participant.firstName.toLowerCase().includes(searchTermLower) ||
                  participant.lastName.toLowerCase().includes(searchTermLower) ||
                  `${participant.firstName} ${participant.lastName}`.toLowerCase().includes(searchTermLower)
                );
              });
            });
          }

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
                role: p.role,
              })),
              lastMessage: chat.lastMessage
                ? {
                    content: chat.lastMessage.content,
                    type: chat.lastMessage.type,
                    createdAt: chat.lastMessage.createdAt,
                    sender: {
                      id: chat.lastMessage.sender._id,
                      firstName: chat.lastMessage.sender.firstName,
                      lastName: chat.lastMessage.sender.lastName,
                      profilePicture: chat.lastMessage.sender.profilePicture,
                      role: chat.lastMessage.sender.role,
                    },
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
  const { senderId, veterinaireId, content, contentType, clientId } = data;

  if (!senderId || !veterinaireId || !content) {
    ws.send(JSON.stringify({
      type: 'ERROR',
      message: 'senderId, veterinaireId, et content sont requis',
    }));
    break;
  }

  const sender = await User.findById(senderId);
  if (!sender) {
    ws.send(JSON.stringify({
      type: 'ERROR',
      message: 'Utilisateur expéditeur introuvable',
    }));
    break;
  }

  const role = sender.role;

  if (![UserRole.CLIENT, UserRole.SECRETAIRE, UserRole.VETERINAIRE].includes(role)) {
    ws.send(JSON.stringify({
      type: 'ERROR',
      message: 'Seuls les clients, secrétaires et vétérinaires peuvent envoyer des messages',
    }));
    break;
  }

  // Determine clientId based on role
  let finalClientId: string | undefined;

  if (role === UserRole.CLIENT) {
    finalClientId = senderId; // Client is the sender
  } else if (role === UserRole.VETERINAIRE) {
    if (sender._id.toString() !== veterinaireId) {
      ws.send(JSON.stringify({
        type: 'ERROR',
        message: 'Vétérinaire non autorisé pour ce chat',
      }));
      break;
    }
    if (!clientId) {
      ws.send(JSON.stringify({
        type: 'ERROR',
        message: 'clientId est requis pour un vétérinaire',
      }));
      break;
    }
    finalClientId = clientId;
  } else if (role === UserRole.SECRETAIRE) {
    if (!sender.veterinaireId || sender.veterinaireId.toString() !== veterinaireId) {
      ws.send(JSON.stringify({
        type: 'ERROR',
        message: 'Secrétaire non autorisé pour ce vétérinaire',
      }));
      break;
    }
    if (!clientId) {
      ws.send(JSON.stringify({
        type: 'ERROR',
        message: 'clientId est requis pour un secrétaire',
      }));
      break;
    }
    finalClientId = clientId;
  }

  // Get or create chat with client, vet, and secretaries (if any)
  const chatId = await getOrCreateChat(senderId, veterinaireId, finalClientId);

  const newMessage = await Message.create({
    chatId,
    sender: new Types.ObjectId(senderId),
    type: contentType || MessageType.TEXT,
    content,
    readBy: [new Types.ObjectId(senderId)],
  });

  await Chat.findByIdAndUpdate(chatId, {
    lastMessage: newMessage._id,
    updatedAt: new Date(),
  });

  const chat = await Chat.findById(chatId).populate('participants');
  if (!chat) {
    ws.send(JSON.stringify({
      type: 'ERROR',
      message: 'Chat introuvable',
    }));
    break;
  }

  // Notify all participants
  for (const participant of chat.participants) {
    const participantId = participant._id.toString();
    if (participantId === senderId) continue;

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
            _id: sender._id,
            firstName: sender.firstName,
            lastName: sender.lastName,
            profilePicture: sender.profilePicture,
            role: sender.role,
          },
          createdAt: newMessage.createdAt,
        },
        notification: {
          title: 'Nouveau message',
          body: `${sender.firstName} ${sender.lastName} vous a envoyé un message.`,
          senderId: sender._id,
          chatId,
        },
      }));
    }
  }

  // Respond to sender
  ws.send(JSON.stringify({
    type: 'MESSAGE_SENT',
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
