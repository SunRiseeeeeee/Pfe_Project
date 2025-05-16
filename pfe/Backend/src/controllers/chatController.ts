// src/controllers/chatController.ts

import { Request, Response, NextFunction } from 'express';
import { Types } from 'mongoose';
import fs from 'fs/promises';
import path from 'path';
import Message, { MessageType } from '../models/Message';
import Chat from '../models/Chat';
import User, { UserRole } from '../models/User';
import { Server } from 'socket.io';

// Configuration des dossiers d’upload
const UPLOADS_DIR = process.env.UPLOADS_DIR || path.join(__dirname, '..', 'uploads');
const CHAT_UPLOADS_DIR = path.join(UPLOADS_DIR, 'chats');
const USER_SELECT_FIELDS = 'firstName lastName username role profilePicture veterinaireId';

// Création du dossier d’upload de chats si nécessaire
(async () => {
  try {
    await fs.mkdir(CHAT_UPLOADS_DIR, { recursive: true });
  } catch (err) {
    console.error('Erreur création répertoire d’upload chat:', err);
  }
})();

// Socket.IO
let io: Server | null = null;
export const initializeSocket = (socketIo: Server) => {
  io = socketIo;
};

// Helper pour valider les ObjectId
const validateObjectId = (id: string): boolean => Types.ObjectId.isValid(id);




export const sendMessage = async (req: Request, res: Response): Promise<void> => {
  try {
    const { senderId, content, veterinaireId: vetId, recipientId } = req.body;
    const file = (req as any).file;

    // ✅ **Validation de l'expéditeur**
    if (!validateObjectId(senderId)) {
      res.status(400).json({ error: 'ID expéditeur invalide' });
      return;
    }

    const sender = await User.findById(senderId).select('-password');
    if (!sender) {
      res.status(404).json({ error: 'Expéditeur non trouvé' });
      return;
    }

    // ✅ **Détermination du vétérinaire et des secrétaires associés**
    let veterinarian: Types.ObjectId;
    let secretaries: Types.ObjectId[] = [];

    switch (sender.role) {
      case UserRole.CLIENT:
        if (!vetId || !validateObjectId(vetId)) {
          res.status(400).json({ error: 'ID vétérinaire requis' });
          return;
        }
        veterinarian = new Types.ObjectId(vetId);
        break;

      case UserRole.VETERINAIRE:
        if (!recipientId || !validateObjectId(recipientId)) {
          res.status(400).json({ error: 'ID client requis' });
          return;
        }
        veterinarian = sender._id;
        break;

      case UserRole.SECRETAIRE:
        if (!sender.veterinaireId) {
          res.status(403).json({ error: 'Secrétaire non associé' });
          return;
        }
        veterinarian = sender.veterinaireId;
        break;

      default:
        res.status(403).json({ error: 'Rôle non autorisé' });
        return;
    }

    // Récupérer les secrétaires associés
    secretaries = await User.find({
      role: UserRole.SECRETAIRE,
      veterinaireId: veterinarian,
    }).distinct('_id');

    // ✅ **Liste des participants**
    const participants = Array.from(new Set([senderId, veterinarian, ...secretaries])).sort((a, b) =>
      a.toString().localeCompare(b.toString())
    );

    // ✅ **Recherche ou création du chat**
    let chat = await Chat.findOne({
      participants: { $all: participants, $size: participants.length },
    }).populate([
      { path: 'participants', select: '-password' },
      { path: 'lastMessage', populate: { path: 'sender', select: '-password' } },
    ]);

    if (!chat) {
      chat = new Chat({
        participants,
        veterinaireId: veterinarian,
        isGroup: true,
        groupName:
          sender.role === UserRole.CLIENT ? 'Discussion client→vétérinaire' : 'Discussion vétérinaire→client',
        unreadCount: 0,
      });
      await chat.save();
      await chat.populate([
        { path: 'participants', select: '-password' },
        { path: 'lastMessage', populate: { path: 'sender', select: '-password' } },
      ]);
    }

    // ✅ **Détermination du type de message**
    let messageType = MessageType.TEXT;
    let messageContent = content ? content.trim() : '';

    if (file) {
  const url = `${req.protocol}://${req.get('host')}/uploads/chats/${file.filename}`;
  messageContent = url;
      if (file.mimetype.startsWith('image/')) messageType = MessageType.IMAGE;
      else if (file.mimetype.startsWith('video/')) messageType = MessageType.VIDEO;
      else if (file.mimetype.startsWith('audio/')) messageType = MessageType.AUDIO;
      else messageType = MessageType.FILE;
    }

    if (!messageContent) {
      if (file?.path) await fs.unlink(file.path).catch(() => {});
      res.status(400).json({ error: 'Contenu vide' });
      return;
    }

    // ✅ **Création du message**
    const message = await Message.create({
      chatId: chat._id,
      sender: senderId,
      type: messageType,
      content: messageContent,
      readBy: [senderId],
    });

    chat.lastMessage = message.id;
    chat.updatedAt = new Date();
    await chat.save();

    const populatedMessage = await Message.populate(message, {
      path: 'sender',
      select: '-password',
    });

    // ✅ **Envoi en temps réel (Socket.IO)**
    const response = { message: populatedMessage, chat };

    // ✔️ **Vérification stricte de io avant l'émission d'événements**
    if (io) {
      const socket = io; // Capture io in a local variable to ensure TypeScript knows it's not null
      participants.forEach((id) => {
        socket.to(id.toString()).emit('newMessage', response.message);
      });

      // Si le chat vient juste d'être créé, on émet l'événement "newChat"
      if (Date.now() - chat.createdAt.getTime() < 1000) {
        participants.forEach((id) => {
          socket.to(id.toString()).emit('newChat', response.chat);
        });
      }
    } else {
      console.warn('Socket.IO non initialisé, pas de notification en temps réel');
    }

    // ✅ **Réponse HTTP**
    res.status(201).json(response);
  } catch (err) {
    console.error('Erreur sendMessage:', err);
    if ((req as any).file?.path) await fs.unlink((req as any).file.path).catch(() => {});
    res.status(500).json({
      error: 'Erreur serveur',
      details: process.env.NODE_ENV === 'development' ? (err as Error).message : undefined,
    });
  }
};



// getConversations
export const getConversations = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { page = '1', search } = req.query;

    if (!validateObjectId(userId)) {
      res.status(400).json({ error: 'ID utilisateur invalide' });
      return;
    }

    const userObj = new Types.ObjectId(userId);
    const pageNum = Math.max(parseInt(page as string, 10) || 1, 1);
    const limit = 10;
    const skip = (pageNum - 1) * limit;

    // Récupération du rôle de l'utilisateur (CLIENT, VETERINAIRE, SECRETAIRE)
    const currentUser = await User.findById(userObj).select('role');
    if (!currentUser) {
      res.status(404).json({ error: 'Utilisateur non trouvé' });
      return;
    }

const isClient = currentUser.role === ('CLIENT' as UserRole);
const isVeterinaireOrSecretaire = ['VETERINAIRE', 'SECRETAIRE'].includes(currentUser.role as UserRole);


    // Construction de la requête de recherche
    const query: any = { participants: userObj };

    if (search) {

      const searchRole = isClient ? ['VETERINAIRE'] : ['CLIENT'];
      
      const users = await User.find({
        role: { $in: searchRole },
        $or: [
          { firstName: { $regex: search as string, $options: 'i' } },
          { lastName: { $regex: search as string, $options: 'i' } }
        ]
      }).distinct('_id');

      query.participants = { $all: [userObj], $in: users };
    }

    const [total, convs] = await Promise.all([
      Chat.countDocuments(query),
      Chat.find(query)
        .populate('participants', USER_SELECT_FIELDS)
        .populate({ path: 'lastMessage', populate: { path: 'sender', select: USER_SELECT_FIELDS } })
        .sort({ updatedAt: -1 })
        .skip(skip)
        .limit(limit)
    ]);

    const convsWithUnread = await Promise.all(
      convs.map(async (c) => ({
        ...c.toObject(),
        unreadCount: await Message.countDocuments({
          chatId: c._id,
          sender: { $ne: userObj },
          readBy: { $ne: userObj }
        })
      }))
    );

    res.status(200).json({
      conversations: convsWithUnread,
      pagination: {
        currentPage: pageNum,
        totalPages: Math.ceil(total / limit),
        totalItems: total
      }
    });
  } catch (err: any) {
    console.error('Erreur getConversations:', err);
    res.status(500).json({ error: 'Erreur serveur', details: err.message });
  }
};

// getMessages
export const getMessages = async (req: Request, res: Response): Promise<void> => {
  try {
    const { chatId, userId } = req.params;
    const { page = '1' } = req.query;
    if (!validateObjectId(chatId) || !validateObjectId(userId)) {
      res.status(400).json({ error: 'IDs invalides' });
      return;
    }
    const chatObj = new Types.ObjectId(chatId);
    const userObj = new Types.ObjectId(userId);

    const chat = await Chat.findById(chatObj);
    if (!chat || !chat.participants.includes(userObj)) {
      res.status(403).json({ error: 'Accès non autorisé' });
      return;
    }

    const pageNum = Math.max(parseInt(page as string, 10) || 1, 1);
    const limit = 20;
    const skip = (pageNum - 1) * limit;

    const [total, msgs] = await Promise.all([
      Message.countDocuments({ chatId: chatObj }),
      Message.find({ chatId: chatObj })
        .populate('sender', USER_SELECT_FIELDS)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
    ]);

    res.status(200).json({
      messages: msgs.reverse(),
      pagination: {
        currentPage: pageNum,
        totalPages: Math.ceil(total / limit),
        totalItems: total
      }
    });
  } catch (err: any) {
    console.error('Erreur getMessages:', err);
    res.status(500).json({ error: 'Erreur serveur', details: err.message });
  }
};

// markMessagesAsRead
export const markMessagesAsRead = async (req: Request, res: Response): Promise<void> => {
  try {
    const { chatId, userId, messageIds } = req.body;
    if (
      !validateObjectId(chatId) ||
      !validateObjectId(userId) ||
      !Array.isArray(messageIds) ||
      !messageIds.every(validateObjectId)
    ) {
      res.status(400).json({ error: 'Données invalides' });
      return;
    }
    const chatObj = new Types.ObjectId(chatId);
    const userObj = new Types.ObjectId(userId);
    const msgObjs = messageIds.map((id: string) => new Types.ObjectId(id));

    const chat = await Chat.findOne({ _id: chatObj, participants: userObj });
    if (!chat) {
      res.status(403).json({ error: 'Accès non autorisé' });
      return;
    }

    await Message.updateMany(
      {
        _id: { $in: msgObjs },
        chatId: chatObj,
        sender: { $ne: userObj },
        readBy: { $ne: userObj }
      },
      { $addToSet: { readBy: userObj } }
    );
    if (io) {
      const socket = io;
      chat.participants
        .filter(p => !p.equals(userObj))
        .forEach(p => {
          socket.to(p.toString()).emit('messagesRead', {
            chatId,
            messageIds,
            readBy: userId
          });
        });
    } else {
      console.warn('Socket.IO non initialisé, pas de notification de lecture');
    }
    
    res.status(200).json({ success: true });
  } catch (err: any) {
    console.error('Erreur markMessagesAsRead:', err);
    res.status(500).json({ error: 'Erreur serveur', details: err.message });
  }
};
