import { RequestHandler } from "express";
import { ServiceService, IServiceInput } from "../services/serviceService";

/**
 * Crée un nouveau service
 */
export const createService: RequestHandler = async (req, res, next) => {
  try {
    const input: IServiceInput = req.body;
    const service = await ServiceService.createService(input);
    res.status(201).json(service);
  } catch (err) {
    next(err);
  }
};

/**
 * Récupère tous les services
 */
export const getAllServices: RequestHandler = async (req, res, next) => {
  try {
    const services = await ServiceService.getAllServices();
    res.json(services);
  } catch (err) {
    next(err);
  }
};

/**
 * Récupère un service par ID
 */
export const getServiceById: RequestHandler = async (req, res, next) => {
  try {
    const { id } = req.params;
    const service = await ServiceService.getServiceById(id);
    if (!service) {
      res.status(404).json({ message: "Service non trouvé" });
      return;
    }
    res.json(service);
  } catch (err) {
    next(err);
  }
};

/**
 * Met à jour un service existant
 */
export const updateService: RequestHandler = async (req, res, next) => {
  try {
    const { id } = req.params;
    const update: Partial<IServiceInput> = req.body;
    const service = await ServiceService.updateService(id, update);
    if (!service) {
      res.status(404).json({ message: "Service non trouvé" });
      return;
    }
    res.json(service);
  } catch (err) {
    next(err);
  }
};

/**
 * Supprime un service par ID
 */
export const deleteService: RequestHandler = async (req, res, next) => {
  try {
    const { id } = req.params;
    const service = await ServiceService.deleteService(id);
    if (!service) {
      res.status(404).json({ message: "Service non trouvé" });
      return;
    }
    res.json({ message: "Service supprimé" });
  } catch (err) {
    next(err);
  }
};
