// src/services/serviceService.ts

import { Types } from "mongoose";
import Service, { IService } from "../models/Service";

export interface IServiceInput {
  name: string;
  description?: string;
  image?: string;
}

export class ServiceService {
  /**
   * Crée un nouveau service
   */
  static async createService(input: IServiceInput): Promise<IService> {
    const service = new Service(input);
    return service.save();
  }

  /**
   * Récupère tous les services
   */
  static async getAllServices(): Promise<IService[]> {
    return Service.find()
      .sort({ createdAt: -1 })
      .exec();
  }

  /**
   * Récupère un service par son ID
   */
  static async getServiceById(id: string): Promise<IService | null> {
    if (!Types.ObjectId.isValid(id)) return null;
    return Service.findById(id).exec();
  }

  /**
   * Met à jour un service existant
   */
  static async updateService(
    id: string,
    update: Partial<IServiceInput>
  ): Promise<IService | null> {
    if (!Types.ObjectId.isValid(id)) return null;
    return Service.findByIdAndUpdate(
      id,
      { $set: update },
      { new: true, runValidators: true }
    ).exec();
  }

  /**
   * Supprime un service par son ID
   */
  static async deleteService(id: string): Promise<IService | null> {
    if (!Types.ObjectId.isValid(id)) return null;
    return Service.findByIdAndDelete(id).exec();
  }
}
