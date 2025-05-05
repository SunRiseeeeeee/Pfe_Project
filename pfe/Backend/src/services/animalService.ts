import Animal, { IAnimal } from "../models/Animal";




// Vérifie si un utilisateur possède déjà un animal avec un certain nom
export const getAnimalByName = async (userId: string, name: string) => {
  return await Animal.findOne({ owner: userId, name }).populate("owner", "username");
};

/**
 * 📌 Ajouter un animal pour un utilisateur
 */
export const createAnimal = async (userId: string, animalData: Partial<IAnimal>): Promise<IAnimal> => {
  // ✅ Si l'image est un chemin local, on la transforme en URL publique
  if (animalData.picture && typeof animalData.picture === 'string' && !animalData.picture.startsWith('http')) {
    const filename = animalData.picture.split(/[\\/]/).pop(); // extrait le nom du fichier
    animalData.picture = `http://localhost:3000/uploads/animals/${filename}`;
  }

  const newAnimal = new Animal({ ...animalData, owner: userId });
  await newAnimal.save();
  return await newAnimal.populate("owner", "username");
};



/**
 * 📌 Récupérer tous les animaux d'un utilisateur
 */
export const getAnimalsByUser = async (userId: string): Promise<IAnimal[]> => {
  return await Animal.find({ owner: userId }).populate("owner", "username");
};

export const getAnimalById = async (userId: string, animalId: string): Promise<IAnimal | null> => {
  return await Animal.findOne({ _id: animalId, owner: userId }).populate("owner", "username");
};

/**
 * 📌 Mettre à jour un animal d'un utilisateur
 */
export const updateAnimal = async (
  userId: string,
  animalId: string,
  updateData: Partial<IAnimal>
): Promise<IAnimal | null> => {
  const allowedFields: (keyof IAnimal)[] = ['name', 'species', 'breed', 'gender', 'birthDate', 'picture'];
  const sanitizedUpdate: Partial<IAnimal> = {};

  for (const key of allowedFields) {
    if (key in updateData) {
      sanitizedUpdate[key] = updateData[key];
    }
  }

  return await Animal.findOneAndUpdate(
    { _id: animalId, owner: userId },
    sanitizedUpdate,
    { new: true }
  ).populate("owner", "username");
};


/**
 * 📌 Supprimer un animal d'un utilisateur
 */
export const deleteAnimal = async (userId: string, animalId: string): Promise<IAnimal | null> => {
  return await Animal.findOneAndDelete({ _id: animalId, owner: userId });
};
