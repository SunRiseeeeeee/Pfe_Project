import cron from "node-cron";
import { Server } from "socket.io";
import Appointment, { AppointmentStatus } from "../models/Appointment";
import User from "../models/User";
import Notification from "../models/Notification";

// Fonction pour créer une notification in-app et émettre un événement Socket.IO
const createInAppNotification = async (
  io: Server,
  userId: string,
  appointment: any,
  clientName: string
): Promise<void> => {
  const appointmentDate = new Date(appointment.date).toLocaleString();
  const notification = await Notification.create({
    userId,
    appointmentId: appointment._id,
    message: `Bonjour ${clientName}, votre rendez-vous est prévu le ${appointmentDate}.`,
  });

  // Émettre l'événement Socket.IO au client spécifique
  io.to(userId).emit("newNotification", {
    id: notification.id.toString(),
    appointmentId: notification.appointmentId.toString(),
    message: notification.message,
    read: notification.read,
    createdAt: notification.createdAt,
  });

  console.log(`In-app notification created and emitted for appointment ${appointment._id} for user ${userId}`);
};

// Fonction pour vérifier et créer les notifications
export const checkAndSendReminders = async (io: Server): Promise<void> => {
  try {
    const now = new Date();
    const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in25Hours = new Date(now.getTime() + 25 * 60 * 60 * 1000);

    // Trouver les rendez-vous acceptés dans les prochaines 24 à 25 heures
    const upcomingAppointments = await Appointment.find({
      date: { $gte: in24Hours, $lte: in25Hours },
      status: AppointmentStatus.ACCEPTED,
      notificationSent: false,
    })
      .populate("clientId", "firstName lastName")
      .populate("animalId", "name");

    console.log(`Found ${upcomingAppointments.length} upcoming accepted appointments`);

    for (const appointment of upcomingAppointments) {
      const client = appointment.clientId as any;
      if (client) {
        await createInAppNotification(
          io,
          client._id.toString(),
          {
            ...appointment.toObject(),
            animalId: (appointment.animalId as any)?.name || appointment.animalId,
          },
          `${client.firstName} ${client.lastName}`
        );

        // Marquer la notification comme envoyée
        appointment.notificationSent = true;
        await appointment.save();
      } else {
        console.warn(`Client not found for appointment ${appointment._id}`);
      }
    }
  } catch (error) {
    console.error("[checkAndSendReminders] Error:", error);
  }
};

// Planifier la tâche avec node-cron (toutes les heures)
export const startReminderCronJob = (io: Server) => {
  cron.schedule("0 * * * *", () => {
    console.log("Checking for upcoming accepted appointments...");
    checkAndSendReminders(io);
  });
};