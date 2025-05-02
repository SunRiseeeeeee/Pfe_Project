import Appointment, { IAppointment, AppointmentStatus } from "../models/Appointment";

/**
 * Créer un nouveau rendez-vous
 * @param appointmentData - Données du rendez-vous
 * @returns Le rendez-vous créé
 */
export const createAppointment = async (appointmentData: Partial<IAppointment>) => {
  const appointment = new Appointment({
    ...appointmentData,
    status: AppointmentStatus.PENDING, // Par défaut, le rendez-vous est en attente
  });
  return await appointment.save();
};


/**
 * Récupérer un rendez-vous par ID
 * @param id - ID du rendez-vous
 * @returns Le rendez-vous correspondant ou null
 */
export const getAppointmentById = async (id: string) => {
  return await Appointment.findById(id)
    .populate("veterinaireId", "-password -refreshToken")  // Exclure les champs sensibles du vétérinaire
    .populate("clientId", "-password -refreshToken");      // Exclure les champs sensibles du client
};

/**
 * Récupérer tous les rendez-vous d'un client spécifique
 * @param clientId - ID du client
 * @returns Liste des rendez-vous du client avec infos vétérinaire
 */
export const getAppointmentsByClient = async (clientId: string) => {
  return await Appointment.find({ clientId }).populate("veterinaireId", "-password -refreshToken");
};

/**
 * Récupérer tous les rendez-vous d'un vétérinaire spécifique (statut PENDING uniquement)
 * @param veterinaireId - ID du vétérinaire
 * @returns Liste des rendez-vous en attente avec infos du client
 */
export const getAppointmentsByVeterinaire = async (veterinaireId: string) => {
  return await Appointment.find({ veterinaireId, status: "PENDING" }).populate("clientId", "-password -refreshToken");
};


/**
 * Mettre à jour un rendez-vous
 * @param id - ID du rendez-vous
 * @param updateData - Données mises à jour
 * @returns Le rendez-vous mis à jour ou null
 */
export const updateAppointment = async (id: string, updateData: Partial<IAppointment>) => {
  // Mise à jour du rendez-vous
  const updatedAppointment = await Appointment.findByIdAndUpdate(id, updateData, { new: true });

  if (!updatedAppointment) {
    throw new Error("Rendez-vous non trouvé");
  }

  return updatedAppointment;
};

/**
 * Supprimer un rendez-vous
 * @param id - ID du rendez-vous
 * @returns Le rendez-vous supprimé ou null
 */
export const deleteAppointment = async (id: string) => {
  const deletedAppointment = await Appointment.findByIdAndDelete(id);

  if (!deletedAppointment) {
    throw new Error("Rendez-vous non trouvé");
  }

  return deletedAppointment;
};

/**
 * Accepter un rendez-vous
 * @param id - ID du rendez-vous
 * @returns Le rendez-vous mis à jour ou null
 */
export const acceptAppointment = async (id: string) => {
  const acceptedAppointment = await Appointment.findByIdAndUpdate(
    id,
    { status: AppointmentStatus.ACCEPTED },
    { new: true }
  );

  if (!acceptedAppointment) {
    throw new Error("Rendez-vous non trouvé");
  }

  return acceptedAppointment;
};

/**
 * Refuser un rendez-vous
 * @param id - ID du rendez-vous
 * @returns Le rendez-vous mis à jour ou null
 */
export const rejectAppointment = async (id: string) => {
  const rejectedAppointment = await Appointment.findByIdAndUpdate(
    id,
    { status: AppointmentStatus.REJECTED },
    { new: true }
  );

  if (!rejectedAppointment) {
    throw new Error("Rendez-vous non trouvé");
  }

  return rejectedAppointment;
};
