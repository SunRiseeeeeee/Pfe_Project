import { Request, Response, NextFunction } from 'express';
import mongoose, { Types } from 'mongoose';
import fs from 'fs/promises';
import path from 'path';
import Message, { MessageType } from '../models/Message';
import Chat from '../models/Chat';
import User, { UserRole } from '../models/User';
import { Server } from 'socket.io';
import multer from 'multer';

// Configuration des chemins d'upload
const uploadsDir = process.env.UPLOAD_DIR || path.join(__dirname, '..', 'uploads');
const postsUploadDir = path.join(uploadsDir, 'posts');

// Création des répertoires si inexistants
(async () => {
  try {
    await fs.mkdir(postsUploadDir, { recursive: true });
  } catch (err) {
    console.error('Erreur création répertoire upload:', err);
  }
})();

// Gestion Socket.IO
let io: Server | null = null;
export const initializeSocket = (socketIo: Server) => {
  io = socketIo;
};

// Constantes
const USER_SELECT_FIELDS = 'firstName lastName username role profilePicture';
const ALLOWED_CHAT_ROLES = [UserRole.CLIENT, UserRole.VETERINAIRE];

// Helper functions
const validateObjectId = (id: string): boolean => Types.ObjectId.isValid(id);
const isAllowedChatParticipant = (role: UserRole): boolean => ALLOWED_CHAT_ROLES.includes(role);

// Middleware de gestion des erreurs Multer
export const handleMulterError = (err: unknown, req: Request, res: Response, next: NextFunction): void => {
  if (err instanceof multer.MulterError) {
    res.status(400).json({ error: err.message });
  } else if (err instanceof Error) {
    res.status(400).json({ error: err.message });
  } else {
    next(err);
  }
};


export const sendMessage = async (req: Request, res: Response): Promise<void> => {
    try {
      const { senderId, recipientId, content } = req.body;
      const file = req.file;
  
      // Validation des IDs
      if (!validateObjectId(senderId) || !validateObjectId(recipientId)) {
        res.status(400).json({ error: 'Format des IDs invalide' });
        return;
      }
  
      const senderObjectId = new Types.ObjectId(senderId);
      const recipientObjectId = new Types.ObjectId(recipientId);
  
      // Récupération des participants
      const [sender, recipient] = await Promise.all([
        User.findById(senderObjectId).select(USER_SELECT_FIELDS),
        User.findById(recipientObjectId).select(USER_SELECT_FIELDS)
      ]);
  
      if (!sender || !recipient) {
        res.status(404).json({ error: 'Participant non trouvé' });
        return;
      }
  
      // Validation des rôles
      if (!(sender.role !== recipient.role && ALLOWED_CHAT_ROLES.includes(sender.role))) {
        res.status(403).json({ error: 'Conversation non autorisée entre ces rôles' });
        return;
      }
  
      // Gestion du chat existant ou nouveau
      let chat = await Chat.findOneAndUpdate(
        { participants: { $all: [senderObjectId, recipientObjectId] }},
        { 
          $setOnInsert: { 
            participants: [senderObjectId, recipientObjectId],
            createdAt: new Date(),
            unreadCount: 0
          }
        },
        { 
          upsert: true,
          new: true,
          setDefaultsOnInsert: true 
        }
      ).populate('participants', USER_SELECT_FIELDS);
  
      if (!chat) {
        throw new Error('Erreur lors de la création/récupération du chat');
      }
  
      // Gestion du contenu du message
      let messageType = MessageType.TEXT;
      let messageContent = content?.trim() || '';
      let fileUrl = '';
  
      if (file) {
        fileUrl = `http://localhost:3000/uploads/chats/${file.filename}`;
        messageContent = fileUrl;
  
        // Détermination du type de message
        if (file.mimetype.startsWith('image/')) {
          messageType = MessageType.IMAGE;
        } else if (file.mimetype.startsWith('video/')) {
          messageType = MessageType.VIDEO;
        } else if (file.mimetype.startsWith('audio/')) {
          messageType = MessageType.AUDIO;
        } else {
          messageType = MessageType.FILE;
        }
      }
  
      if (!messageContent) {
        if (file?.path) await fs.unlink(file.path);
        res.status(400).json({ error: 'Le contenu du message ne peut pas être vide' });
        return;
      }
  
      // Création du message
      const message = await Message.create({
        chatId: chat._id,
        sender: senderObjectId,
        type: messageType,
        content: messageContent,
        readBy: [senderObjectId]
      });
  
      // Mise à jour du chat
      const updatedChat = await Chat.findByIdAndUpdate(
        chat._id,
        {
          $set: { 
            lastMessage: message._id,
            updatedAt: new Date() 
          },
          $inc: { unreadCount: 1 }
        },
        { new: true }
      ).populate('participants', USER_SELECT_FIELDS);
  
      if (!updatedChat) {
        throw new Error('Échec de la mise à jour du chat');
      }
  
      // Préparation de la réponse
      const populatedMessage = await Message.populate(message, {
        path: 'sender',
        select: USER_SELECT_FIELDS
      });
  
      const responseData = {
        message: populatedMessage.toObject(),
        chat: updatedChat.toObject()
      };
  
      // Notification via Socket.IO
      if (io) {
        const recipientIdString = recipientId.toString();
        const senderIdString = senderId.toString();
        
        io.to(recipientIdString).emit('newMessage', responseData.message);
        io.to(senderIdString).emit('newMessage', responseData.message);
  
        if (Date.now() - updatedChat.createdAt.getTime() < 1000) {
          io.to(senderIdString).emit('newChat', responseData.chat);
          io.to(recipientIdString).emit('newChat', responseData.chat);
        }
      }
  
      res.status(201).json(responseData);
  
    } catch (error: unknown) {
      // Nettoyage en cas d'erreur
      if (req.file?.path) {
        try {
          await fs.unlink(req.file.path);
        } catch (unlinkError) {
          console.error('Erreur de nettoyage du fichier:', unlinkError);
        }
      }
      
      const errorMessage = error instanceof Error ? error.message : 'Erreur inconnue';
      console.error('Erreur lors de l\'envoi du message:', error);
      
      res.status(500).json({ 
        error: 'Une erreur est survenue lors de l\'envoi du message',
        details: process.env.NODE_ENV === 'development' ? errorMessage : undefined
      });
    }
  };


interface ConversationQuery {
  page?: string;
  firstName?: string;
  lastName?: string;
  startDate?: string;
  endDate?: string;
}

export const getConversations = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { page = "1", firstName, lastName, startDate, endDate } = req.query as ConversationQuery;

    // Validate userId
    if (!validateObjectId(userId)) {
      res.status(400).json({ error: "ID utilisateur invalide" });
      return;
    }

    const userObjectId = new Types.ObjectId(userId);

    // Validate date filters
    let dateFilter: any = {};
    if (startDate || endDate) {
      if (startDate && isNaN(Date.parse(startDate))) {
        res.status(400).json({ error: "startDate invalide, utilisez un format ISO 8601" });
        return;
      }
      if (endDate && isNaN(Date.parse(endDate))) {
        res.status(400).json({ error: "endDate invalide, utilisez un format ISO 8601" });
        return;
      }
      if (startDate && endDate && new Date(startDate) > new Date(endDate)) {
        res.status(400).json({ error: "startDate ne peut pas être postérieur à endDate" });
        return;
      }
      dateFilter = {
        createdAt: {
          ...(startDate && { $gte: new Date(startDate) }),
          ...(endDate && { $lte: new Date(endDate) }),
        },
      };
    }

    // Pagination parameters
    const limit = 10;
    const pageNumber = Math.max(parseInt(page, 10), 1); // Ensure page is at least 1
    const skip = (pageNumber - 1) * limit;

    // Build filter for participants (firstName or lastName)
    const participantFilter: any = { _id: { $ne: userObjectId } }; // Exclude the user themselves
    if (firstName || lastName) {
      const nameFilters: any[] = [];
      if (firstName) {
        nameFilters.push({ firstName: { $regex: firstName, $options: "i" } });
      }
      if (lastName) {
        nameFilters.push({ lastName: { $regex: lastName, $options: "i" } });
      }
      participantFilter.$or = nameFilters;
    }

    // Find users matching the name filter
    const matchingUsers = await User.find(participantFilter).select("_id");
    const matchingUserIds = matchingUsers.map((user) => user._id);

    // Find chatIds with messages in the specified time range
    let chatIdsWithMessages: Types.ObjectId[] = [];
    if (startDate || endDate) {
      const messages = await Message.find({
        ...dateFilter,
        chatId: { $in: await Chat.find({ participants: userObjectId }).distinct("_id") },
      }).distinct("chatId");
      chatIdsWithMessages = messages.map((id) => new Types.ObjectId(id.toString()));
    }

    // Build query for conversations
    const conversationQuery: any = {
      participants: { $all: [userObjectId], $in: matchingUserIds.length ? matchingUserIds : undefined },
      ...(chatIdsWithMessages.length && { _id: { $in: chatIdsWithMessages } }),
    };

    // Get total count of matching conversations for pagination
    const totalConversations = await Chat.countDocuments(conversationQuery);

    // Fetch conversations with pagination
    const conversations = await Chat.find(conversationQuery)
      .populate("participants", USER_SELECT_FIELDS)
      .populate({
        path: "lastMessage",
        populate: { path: "sender", select: USER_SELECT_FIELDS },
      })
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(limit);

    // Calculate unread message counts for each conversation
    const conversationsWithUnreadCount = await Promise.all(
      conversations.map(async (conversation) => {
        const unreadCount = await Message.countDocuments({
          chatId: conversation._id,
          readBy: { $ne: userObjectId },
          sender: { $ne: userObjectId },
        });

        return {
          ...conversation.toObject(),
          unreadCount,
        };
      })
    );

    // Prepare response with pagination metadata
    res.status(200).json({
      conversations: conversationsWithUnreadCount,
      currentPage: pageNumber,
      totalPages: Math.ceil(totalConversations / limit),
      totalConversations,
    });
  } catch (error) {
    console.error("Erreur récupération conversations:", error);
    res.status(500).json({ error: "Erreur serveur interne" });
  }
};
/**
 * Récupération des messages d'un chat
 */
interface MessageQuery {
  page?: string;
}

export const getMessages = async (req: Request, res: Response): Promise<void> => {
  try {
    const { chatId, userId } = req.params;
    const { page = "1" } = req.query as MessageQuery;

    // Validation des IDs
    if (!validateObjectId(chatId) || !validateObjectId(userId)) {
      res.status(400).json({ error: "Format des IDs invalide" });
      return;
    }

    const chatObjectId = new Types.ObjectId(chatId);
    const userObjectId = new Types.ObjectId(userId);

    // Vérification de l'existence du chat
    const chat = await Chat.findById(chatObjectId);
    if (!chat) {
      res.status(404).json({ error: "Chat non trouvé" });
      return;
    }

    // Vérification de la participation
    const isParticipant = chat.participants.some((participant) =>
      participant.toString() === userObjectId.toString()
    );

    if (!isParticipant) {
      res.status(403).json({ error: "Utilisateur non participant à ce chat" });
      return;
    }

    // Pagination parameters
    const limit = 15;
    const pageNumber = Math.max(parseInt(page, 10), 1); // Ensure page is at least 1
    const skip = (pageNumber - 1) * limit;

    // Get total count of messages for pagination
    const totalMessages = await Message.countDocuments({ chatId: chatObjectId });

    // Récupération des messages avec pagination
    const messages = await Message.find({ chatId: chatObjectId })
      .populate("sender", USER_SELECT_FIELDS)
      .sort({ createdAt: 1 })
      .skip(skip)
      .limit(limit);

    // Prepare response with pagination metadata
    res.status(200).json({
      messages,
      currentPage: pageNumber,
      totalPages: Math.ceil(totalMessages / limit),
      totalMessages,
    });
  } catch (error) {
    console.error("Erreur récupération messages:", error);
    res.status(500).json({ error: "Erreur serveur interne" });
  }
};

export const markMessagesAsRead = async (req: Request, res: Response): Promise<void> => {
  try {
    const { chatId, userId, messageIds } = req.body;

    // Validation des IDs
    if (!validateObjectId(chatId) || !validateObjectId(userId)) {
      res.status(400).json({ error: 'Format des IDs invalide' });
      return;
    }

    if (!Array.isArray(messageIds) || !messageIds.every(validateObjectId)) {
      res.status(400).json({ error: 'IDs de message invalides' });
      return;
    }

    const chatObjectId = new Types.ObjectId(chatId);
    const userObjectId = new Types.ObjectId(userId);
    const messageObjectIds = messageIds.map(id => new Types.ObjectId(id));

    // Vérification du chat et des messages
    const [chat, messages] = await Promise.all([
      Chat.findById(chatObjectId),
      Message.find({
        _id: { $in: messageObjectIds },
        chatId: chatObjectId
      }).lean()
    ]);

    if (!chat) {
      res.status(404).json({ error: 'Chat non trouvé' });
      return;
    }

    // Vérification que l'utilisateur est bien destinataire
    const isRecipient = chat.participants.some(participant => 
      participant.equals(userObjectId)
    ) && messages.every(message => 
      !new Types.ObjectId(message.sender).equals(userObjectId)
    );

    if (!isRecipient) {
      res.status(403).json({ error: 'Seul le destinataire peut marquer les messages comme lus' });
      return;
    }

    // Marquage des messages comme lus
    await Message.updateMany(
      { 
        _id: { $in: messageObjectIds },
        chatId: chatObjectId
      },
      { $addToSet: { readBy: userObjectId } }
    );

    // Notification à l'expéditeur via Socket.IO
    const senderId = chat.participants.find(id => !id.equals(userObjectId));
    if (senderId && io) {
      io.to(senderId.toString()).emit('messagesRead', {
        chatId,
        messageIds,
        readBy: userId
      });
    }

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Erreur marquage messages comme lus:', error);
    res.status(500).json({ error: 'Erreur serveur interne' });
  }
};