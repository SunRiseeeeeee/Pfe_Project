import WebSocket, { WebSocketServer } from 'ws';
import Message, { MessageType } from '../models/Message';
import mongoose from 'mongoose';

const clients = new Map<string, WebSocket>();
const wss = new WebSocketServer({ port: 3001 });

/**
 * Vérifie si un ID est un ObjectId valide de MongoDB.
 */
const isValidObjectId = (id: string) => mongoose.Types.ObjectId.isValid(id);

wss.on('connection', (ws: WebSocket) => {
  console.log('Client connecté.');

  ws.on('message', async (message: string) => {
    console.log(`Message reçu : ${message}`);

    try {
      const parsedMessage = JSON.parse(message);

      // 🔹 Enregistrement du client
      if (parsedMessage.senderId) {
        clients.set(parsedMessage.senderId, ws);
        ws.send(JSON.stringify({
          status: 'success',
          message: `Client ${parsedMessage.senderId} enregistré.`
        }));
      }

      // 🔹 Sauvegarde du message dans MongoDB et envoi au destinataire
      if (parsedMessage.chatId && parsedMessage.content && parsedMessage.recipientId) {
        
        // ✅ Vérification des IDs
        if (!isValidObjectId(parsedMessage.chatId) || !isValidObjectId(parsedMessage.senderId)) {
          throw new Error("chatId ou senderId n'est pas un ObjectId valide");
        }

        const newMessage = new Message({
          chatId: new mongoose.Types.ObjectId(parsedMessage.chatId),
          sender: new mongoose.Types.ObjectId(parsedMessage.senderId),
          type: MessageType.TEXT,
          content: parsedMessage.content,
          readBy: [],
        });

        await newMessage.save();
        console.log('Message sauvegardé dans la base de données');

        // 🔹 Envoi du message en temps réel au destinataire s'il est connecté
        const recipientSocket = clients.get(parsedMessage.recipientId);

        if (recipientSocket && recipientSocket.readyState === WebSocket.OPEN) {
          recipientSocket.send(JSON.stringify({
            senderId: parsedMessage.senderId,
            content: parsedMessage.content,
            timestamp: Date.now()
          }));

          console.log(`Message envoyé à ${parsedMessage.recipientId}`);
        } else {
          console.log(`${parsedMessage.recipientId} n'est pas connecté.`);
        }

        // 🔹 Accusé de réception à l'expéditeur
        ws.send(JSON.stringify({
          status: 'success',
          message: `Message envoyé à ${parsedMessage.recipientId}`
        }));
      }

    } catch (e) {
      console.error('Erreur de parsing JSON:', (e as Error).message);
      ws.send(JSON.stringify({
        status: 'error',
        message: `Erreur: ${(e as Error).message}`
      }));
    }
  });

  ws.on('close', () => {
    console.log('Client déconnecté.');
  });
});

console.log('WebSocket en écoute sur ws://localhost:3001/');
export { wss, clients };
