import Animal, { IAnimal } from "../models/Animal";




// Vérifie si un utilisateur possède déjà un animal avec un certain nom
export const getAnimalByName = async (userId: string, name: string) => {
  return await Animal.findOne({ owner: userId, name });
};
/**
 * 📌 Ajouter un animal pour un utilisateur
 */
export const createAnimal = async (userId: string, animalData: Partial<IAnimal>): Promise<IAnimal> => {
  const newAnimal = new Animal({ ...animalData, owner: userId });
  return await newAnimal.save();
};

/**
 * 📌 Récupérer tous les animaux d'un utilisateur
 */
export const getAnimalsByUser = async (userId: string): Promise<IAnimal[]> => {
  return await Animal.find({ owner: userId }).populate("owner", "name email");
};

/**
 * 📌 Récupérer un animal spécifique d'un utilisateur
 */
export const getAnimalById = async (userId: string, animalId: string): Promise<IAnimal | null> => {
  return await Animal.findOne({ _id: animalId, owner: userId }).populate("owner", "name email");
};

/**
 * 📌 Mettre à jour un animal d'un utilisateur
 */
export const updateAnimal = async (userId: string, animalId: string, updateData: Partial<IAnimal>): Promise<IAnimal | null> => {
  return await Animal.findOneAndUpdate(
    { _id: animalId, owner: userId },
    updateData,
    { new: true }
  );
};

/**
 * 📌 Supprimer un animal d'un utilisateur
 */
export const deleteAnimal = async (userId: string, animalId: string): Promise<IAnimal | null> => {
  return await Animal.findOneAndDelete({ _id: animalId, owner: userId });
};
