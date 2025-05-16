import { Server as SocketIOServer, Socket } from 'socket.io';
import http from 'http';
import express, { Application } from 'express';
import mongoose from 'mongoose';
import Chat from '../models/Chat';
import Message, { IMessage, MessageType } from '../models/Message';
import User from '../models/User';

// Initialisation Express + serveur HTTP
const app: Application = express();
const server = http.createServer(app);

// Middleware JSON
app.use(express.json());

// Socket.IO avec options CORS
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env.CORS_ORIGIN?.split(',') || '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    credentials: true,
  },
  path: '/socket.io',
  transports: ['websocket', 'polling'],
  pingInterval: 10000,
  pingTimeout: 5000,
  cookie: false,
});

// Utilitaire : validation ObjectId
function isValidObjectId(id?: string): boolean {
  return !!id && mongoose.isValidObjectId(id);
}

// Types
interface IMessagePayload {
  senderId: string;
  recipientId: string;  // vétérinaire
  content: string;
  chatId?: string;
  type?: MessageType;
}

interface IApiResponse {
  success: boolean;
  error?: string;
  data?: any;
  statusCode?: number;
  timestamp?: number;
}
import { Document, Types } from 'mongoose';

export interface IChat extends Document {
  participants: Types.ObjectId[];
  unreadCount: number;
  lastMessage?: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

// Gestion chat : récupérer ou créer avec client + vétérinaire + secrétaires
async function handleChat(
    senderId: string,
    veterinaireId: string,
    existingChatId?: string
  ): Promise<{ chat: IChat & Document; isNew: boolean }> {
    if (!isValidObjectId(senderId) || !isValidObjectId(veterinaireId)) {
      throw new Error('Invalid user IDs');
    }
  
    console.log(`[handleChat] Fetching users...`);
  
    // On récupère uniquement le vétérinaire
    const veterinaire = await User.findById(veterinaireId);
  
    if (!veterinaire) {
      throw new Error('Veterinaire not found');
    }
    console.log(`[handleChat] Veterinaire found: ${veterinaire._id}`);
  
    // Si un chat existe déjà, on le récupère
    if (existingChatId) {
      if (!isValidObjectId(existingChatId)) throw new Error('Invalid existingChatId');
      const chat = await Chat.findById(existingChatId);
      if (!chat) throw new Error('Chat not found');
      console.log(`[handleChat] Using existing chat: ${chat._id}`);
      return { chat, isNew: false };
    }
  
    console.log(`[handleChat] Finding secretaries...`);
    const secretaires = await User.find({ role: 'SECRETAIRE', veterinaireId: veterinaire._id }).select('_id');
    console.log(`[handleChat] Secretaries found: ${secretaires.length}`);
  
    // On construit les participants sans vérifier l'existence du client
    const participants = [
      mongoose.Types.ObjectId.isValid(senderId) ? new Types.ObjectId(senderId) : senderId,
      veterinaire._id,
      ...secretaires.map(s => s._id)
    ];
    participants.sort();
  
    console.log(`[handleChat] Searching existing chat with participants: ${participants}`);
    const existingChat = await Chat.findOne({
      participants: { $all: participants, $size: participants.length }
    });
  
    if (existingChat) {
      console.log(`[handleChat] Found existing chat: ${existingChat._id}`);
      return { chat: existingChat, isNew: false };
    }
  
    console.log(`[handleChat] Creating new chat...`);
  
    const newChat = await Chat.create({
      participants,
      unreadCount: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  
    console.log(`[handleChat] New chat created: ${newChat._id}`);
  
    return { chat: newChat, isNew: true };
  }
  
  

// Configuration Socket.IO
function setupSocketIO(): void {
  io.on('connection', (socket: Socket) => {
    console.log(`[SOCKET] Connected: ${socket.id}`);

    // Rejoindre toutes les rooms des chats de l'utilisateur
    socket.on('joinChats', async (userId: string) => {
      try {
        if (!isValidObjectId(userId)) throw new Error('Invalid user ID');

        const chats = await Chat.find({ participants: userId }).select('_id').exec();
        chats.forEach(chat => {
          socket.join(chat.id.toString());
          console.log(`[SOCKET] Socket ${socket.id} joined chat ${chat._id}`);
        });
      } catch (err) {
        console.error(`[SOCKET ERROR] joinChats: ${(err as Error).message}`);
        socket.emit('error', { event: 'joinChats', error: (err as Error).message });
      }
    });

// ... (les imports restent les mêmes)

// Envoyer un message - version améliorée
socket.on('sendMessage', async (payload, callback) => {
    console.log('[SOCKET] Raw payload received:', payload);
  
    // Normalisation du payload
    const normalizedPayload = {
      senderId: payload.senderId,
      recipientId: payload.recipientId || payload.veterinaireId, // Support les deux formats
      content: payload.content,
      type: payload.type || 'TEXT',
      chatId: payload.chatId
    };
  
    console.log('[SOCKET] Normalized payload:', normalizedPayload);
  
    // Validation
    if (!normalizedPayload.senderId || !normalizedPayload.recipientId || !normalizedPayload.content) {
      console.error('[ERROR] Validation failed - missing fields');
      return callback?.({
        success: false,
        error: 'senderId, recipientId and content are required',
        statusCode: 400
      });
    }
  
    // Début transaction
    const session = await mongoose.startSession();
    session.startTransaction();
  
    try {
      // 1. Gestion du chat
      const { chat } = await handleChat(
        normalizedPayload.senderId,
        normalizedPayload.recipientId,
        normalizedPayload.chatId
      );
      console.log('[DB] Chat ready:', chat._id);
  
      // 2. Création du message
      const [message] = await Message.create([{
        chatId: chat._id,
        sender: normalizedPayload.senderId,
        type: normalizedPayload.type,
        content: normalizedPayload.content,
        readBy: [normalizedPayload.senderId]
      }], { session });
  
      console.log('[DB] Message created:', message._id);
  
      // 3. Mise à jour du chat
      const updatedChat = await Chat.findByIdAndUpdate(
        chat._id,
        {
          $set: { lastMessage: message._id, updatedAt: new Date() },
          $inc: { unreadCount: 1 }
        },
        { new: true, session }
      ).populate('participants lastMessage');
  
      console.log('[DB] Chat updated:', updatedChat?._id);
  
      // Validation transaction
      await session.commitTransaction();
      session.endSession();
  
      // Diffusion du message
      io.to(chat.id.toString()).emit('newMessage', {
        chat: updatedChat?.toObject(),
        message: message.toObject()
      });
  
      console.log('[SOCKET] Message broadcasted');
  
      callback?.({
        success: true,
        data: {
          chatId: chat._id,
          messageId: message._id
        }
      });
  
    } catch (error) {
      // Annulation transaction en cas d'erreur
      await session.abortTransaction();
      session.endSession();
      
      console.error('[ERROR] Full error:', error);
      
      callback?.({
        success: false,
        error: error instanceof Error ? error.message : 'Database operation failed',
        statusCode: 500
      });
    }
  });
    // Marquer les messages comme lus
    socket.on('markAsRead', async ({ messageIds, userId }: { messageIds: string[]; userId: string }, callback?: (response: IApiResponse) => void) => {
      try {
        if (!Array.isArray(messageIds) || !messageIds.every(isValidObjectId) || !isValidObjectId(userId)) {
          throw new Error('Invalid parameters');
        }

        await Message.updateMany(
          { _id: { $in: messageIds } },
          { $addToSet: { readBy: userId } }
        );

        if (typeof callback === 'function') {
          callback({ success: true, timestamp: Date.now() });
        }
      } catch (err) {
        if (typeof callback === 'function') {
          callback({ success: false, error: (err as Error).message || 'Unknown error', timestamp: Date.now() });
        }
      }
    });

    socket.on('disconnect', (reason) => {
      console.log(`[SOCKET] Disconnected: ${socket.id} Reason: ${reason}`);
    });
  });
}

export { app, server, io, setupSocketIO };
