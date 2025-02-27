import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User, { IUser, UserRole } from "../models/User";

// Définir un type précis pour les détails supplémentaires
interface ExtraDetails {
  profilePicture?: string;
  location?: string;
  details?: {
    specialty?: string;
    workingHours?: string;
  };
  reviews?: any[]; // Ajout de la propriété reviews
}

export class UserService {
  // 🟢 Création d'un utilisateur
  static async createUser(
    firstName: string,
    lastName: string,
    username: string,
    email: string,
    password: string,
    phoneNumber: string,
    role: UserRole,
    extraDetails: ExtraDetails = {} // Valeur par défaut pour éviter "undefined"
  ): Promise<IUser> {
    
    // Vérification si l'email ou le numéro de téléphone existent déjà
    const existingUser = await User.findOne({ $or: [{ email }, { phoneNumber }] });
    if (existingUser) {
      throw new Error("L'email ou le numéro de téléphone est déjà utilisé");
    }

    // Hachage du mot de passe
    const hashedPassword = await bcrypt.hash(password, 10);

    // Création de l'utilisateur avec les champs supplémentaires
    const newUser = new User({
      firstName,
      lastName,
      username,
      email,
      password: hashedPassword,
      phoneNumber,
      role,
      profilePicture: extraDetails.profilePicture || null,
      location: extraDetails.location || null,
      details: extraDetails.details || {}, // S'assurer que `details` est un objet vide par défaut
      reviews: extraDetails.reviews || [] // Initialisation de reviews avec un tableau vide
    });

    await newUser.save();
    return newUser;
  }

  // 🔑 Authentification de l'utilisateur
  static async authenticateUser(username: string, password: string): Promise<string> {
    
    // Recherche d'un utilisateur par son nom d'utilisateur
    const user = await User.findOne({ username });

    if (!user) throw new Error("Utilisateur non trouvé");

    // Vérification du mot de passe
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new Error("Identifiants invalides");

    // Génération du token JWT
    return jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET || "secret", // Utiliser un secret sécurisé en production
      { expiresIn: "1h" }
    );
  }

  // 📝 Modifier les coordonnées d'un utilisateur
  static async updateUser(userId: string, updateData: Partial<IUser>): Promise<IUser | null> {
    return await User.findByIdAndUpdate(userId, updateData, { new: true, runValidators: true });
  }

  // ❌ Supprimer un compte utilisateur
  static async deleteUser(userId: string): Promise<IUser | null> {
    return await User.findByIdAndDelete(userId);
  }

  // 📋 Obtenir tous les utilisateurs d'un rôle spécifique
  static async getUsersByRole(role: UserRole): Promise<IUser[]> {
    return await User.find({ role });
  }

  // 🔍 Récupérer un utilisateur par son ID
  static async getUserById(userId: string): Promise<IUser | null> {
    try {
      // Utilisation de Mongoose pour trouver l'utilisateur par son ID
      const user = await User.findById(userId);
      return user;
    } catch (error) {
      throw new Error("Erreur lors de la récupération de l'utilisateur");
    }
  }
}
