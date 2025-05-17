import { Server as SocketIOServer, Socket } from 'socket.io';
import http from 'http';
import express, { Application } from 'express';
import mongoose, { Types, Document } from 'mongoose';
import Chat from '../models/Chat';
import Message, { MessageType } from '../models/Message';
import User from '../models/User';

// Types

interface IChat {
  participants: Types.ObjectId[];
  unreadCount: number;
  lastMessage?: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

type IChatDocument = IChat & Document;

const app: Application = express();
const server = http.createServer(app);

app.use(express.json());

const io = new SocketIOServer(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    credentials: true,
  },
  path: '/socket.io',
  transports: ['websocket', 'polling'],
  pingInterval: 10000,
  pingTimeout: 5000,
  cookie: false,
});

const isValidObjectId = (id: string) => mongoose.isValidObjectId(id);

const handleChat = async (
  senderId: string,
  veterinaireId: string
): Promise<{ chat: IChatDocument; isNew: boolean }> => {
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
    console.log(`Chat existant trouvé : ${existingChat._id}`);
    return { chat: existingChat, isNew: false };
  }

  const newChat = await Chat.create({
    participants,
    unreadCount: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  console.log(`Nouveau chat créé : ${newChat._id}`);
  return { chat: newChat, isNew: true };
};

io.on('connection', (socket: Socket) => {
  console.log(`[SOCKET] Connecté : ${socket.id}`);

  socket.on('sendMessage', async (payload, callback) => {
    try {
      const { senderId, veterinaireId, content } = payload;

      if (!senderId || !veterinaireId || !content) {
        throw new Error('senderId, veterinaireId et content sont requis.');
      }

      const { chat, isNew } = await handleChat(senderId, veterinaireId);

      const message = await Message.create({
        chatId: chat._id,
        sender: senderId,
        type: MessageType.TEXT,
        content,
        readBy: [senderId],
      });

      await chat.updateOne({
        $set: { lastMessage: message._id, updatedAt: new Date() },
        $inc: { unreadCount: 1 },
      });

      // Important: participants est accessible sur l'instance chat
      chat.participants.forEach((participantId) => {
        io.to(participantId.toString()).emit('newMessage', {
          chatId: chat._id,
          message: message.toObject(),
        });
      });

      console.log(`[SOCKET] Message diffusé aux participants`);

      callback?.({
        success: true,
        data: {
          chatId: chat._id,
          messageId: message._id,
          isNewChat: isNew,
        },
      });
    } catch (error) {
      console.error('[ERROR] sendMessage:', (error as Error).message);
      callback?.({
        success: false,
        error: (error as Error).message,
        statusCode: 500,
      });
    }
  });

  socket.on('disconnect', (reason) => {
    console.log(`[SOCKET] Déconnecté : ${socket.id} Raison : ${reason}`);
  });
});

server.listen(3001, () => {
  console.log('WebSocket en écoute sur ws://localhost:3001');
});

export { app, server, io };
