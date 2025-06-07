import cron from "node-cron";
import { Server } from "socket.io";
import Appointment, { AppointmentStatus } from "../models/Appointment";
import Notification from "../models/Notification";

// Fonction pour créer et envoyer une notification via Socket.IO
const createInAppNotification = async (
  io: Server,
  userId: string,
  appointment: {
    _id: string;
    date: Date;
    animalId: string;
  },
  clientName: string
): Promise<void> => {
  try {
    const formattedDate = new Date(appointment.date).toLocaleString("fr-FR");
const message = `Hello ${clientName}, your appointment for ${appointment.animalId} is scheduled on ${formattedDate}.`;

    const notification = await Notification.create({
      userId,
      appointmentId: appointment._id,
      message,
    });

    io.to(userId).emit("newNotification", {
      id: notification.id.toString(),
      appointmentId: notification.appointmentId.toString(),
      message: notification.message,
      read: notification.read,
      createdAt: notification.createdAt,
    });

    console.log(
      `✅ Notification créée et envoyée pour le rendez-vous ${appointment._id} (user ${userId})`
    );
  } catch (error) {
    console.error("[createInAppNotification] Erreur lors de la création ou de l'envoi :", error);
  }
};

// Fonction principale pour vérifier les rendez-vous et envoyer les rappels
export const checkAndSendReminders = async (io: Server): Promise<void> => {
  try {
    const now = new Date();
    const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in25Hours = new Date(now.getTime() + 25 * 60 * 60 * 1000);

    const appointments = await Appointment.find({
      date: { $gte: in24Hours, $lte: in25Hours },
      status: AppointmentStatus.ACCEPTED,
      notificationSent: false,
    })
      .populate("clientId", "firstName lastName")
      .populate("animalId", "name");

    console.log(`📅 ${appointments.length} rendez-vous acceptés dans les prochaines 24h.`);

    for (const appointment of appointments) {
      const client = appointment.clientId as any;
      const animal = appointment.animalId as any;

      if (client && client._id && animal && animal.name) {
        await createInAppNotification(
          io,
          client._id.toString(),
          {
            _id: appointment.id.toString(),
            date: appointment.date,
            animalId: animal.name,
          },
          `${client.firstName} ${client.lastName}`
        );

        appointment.notificationSent = true;
        await appointment.save();
      } else {
        console.warn(`⚠️ Données manquantes pour le rendez-vous ${appointment._id}`);
      }
    }
  } catch (error) {
    console.error("[checkAndSendReminders] Erreur :", error);
  }
};

// Fonction qui démarre la tâche cron toutes les heures
export const startReminderCronJob = (io: Server): void => {
  cron.schedule("0 * * * *", () => {
    console.log("🕐 Exécution du cron : Vérification des rappels de rendez-vous...");
    checkAndSendReminders(io);
  });
};
