import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User, { IUser, UserRole } from "../models/User";
import mongoose from "mongoose";

// Définir un type précis pour les détails supplémentaires
interface ExtraDetails {
  profilePicture?: string;
  location?: string;
  details?: {
    specialty?: string;
    workingHours?: string;
  };
  reviews?: any[];
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
    extraDetails: ExtraDetails = {}
  ): Promise<IUser> {
    const existingUser = await User.findOne({ $or: [{ email }, { phoneNumber }] });
    if (existingUser) {
      throw new Error("L'email ou le numéro de téléphone est déjà utilisé");
    }

    const hashedPassword = await bcrypt.hash(password, 10);

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
      details: extraDetails.details || {},
      reviews: extraDetails.reviews || [],
      refreshToken: null,
    });

    await newUser.save();
    return newUser;
  }

  // 🔑 Authentification de l'utilisateur avec refresh token
  static async authenticateUser(username: string, password: string) {
    const user = await User.findOne({ username });
    if (!user) throw new Error("Utilisateur non trouvé");

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new Error("Identifiants invalides");

    const accessToken = UserService.generateAccessToken(user.id, user.role);
    const refreshToken = UserService.generateRefreshToken(user.id);

    user.refreshToken = refreshToken;
    await user.save();

    return { accessToken, refreshToken };
  }

  // 🔄 Rafraîchir le token
  static async refreshAccessToken(refreshToken: string) {
    if (!refreshToken) throw new Error("Refresh token requis");

    const user = await User.findOne({ refreshToken });
    if (!user) throw new Error("Token invalide ou expiré");

    try {
      const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET || "refresh_secret") as { id: string };
      const newAccessToken = UserService.generateAccessToken(decoded.id, user.role);
      return { accessToken: newAccessToken };
    } catch (error) {
      throw new Error("Refresh token invalide");
    }
  }

  // ❌ Déconnexion (suppression du refresh token)
  static async logoutUser(refreshToken: string): Promise<void> {
    // Rechercher l'utilisateur par refreshToken
    const user = await User.findOne({ refreshToken });
  
    // Si l'utilisateur n'est pas trouvé, lever une erreur
    if (!user) {
      throw new Error("Utilisateur non trouvé");
    }
  
    // Invalider le refreshToken en le supprimant
    user.refreshToken = null;
    await user.save();
  }
  // 🔑 Génération d'un access token
  static generateAccessToken(userId: string, role: UserRole) {
    return jwt.sign(
      { id: userId, role },
      process.env.JWT_SECRET || "secret",
      { expiresIn: "1h" }
    );
  }

  // 🔄 Génération d'un refresh token
  static generateRefreshToken(userId: string) {
    return jwt.sign(
      { id: userId },
      process.env.JWT_REFRESH_SECRET || "refresh_secret",
      { expiresIn: "7d" }
    );
  }

  // 🟢 Récupérer un utilisateur par son ID
  static async getUserById(userId: string): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("ID utilisateur invalide");
    }
    const user = await User.findById(userId);
    return user;
  }

  // 🟢 Mettre à jour un utilisateur
  static async updateUser(userId: string, updateData: Partial<IUser>): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("ID utilisateur invalide");
    }
    const updatedUser = await User.findByIdAndUpdate(userId, updateData, { new: true });
    return updatedUser;
  }

  // 🟢 Supprimer un utilisateur
  static async deleteUser(userId: string): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("ID utilisateur invalide");
    }
    const deletedUser = await User.findByIdAndDelete(userId);
    return deletedUser;
  }

  // 🟢 Récupérer les utilisateurs par rôle
  static async getUsersByRole(role: UserRole): Promise<IUser[]> {
    const users = await User.find({ role });
    return users;
  }
}