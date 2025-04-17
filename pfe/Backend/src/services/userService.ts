import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User, { IUser, UserRole } from "../models/User";
import mongoose from "mongoose";

interface UserDetails {
  services?: string;
  workingHours?: string;
}

interface ExtraDetails {
  profilePicture?: string;
  MapsLocation?: string;
  description?: string;
  details?: UserDetails;
  reviews?: any[];
  rating?: number;
}

export class UserService {
  static async createUser(
    userData: {
      firstName: string;
      lastName: string;
      username: string;
      email: string;
      password: string;
      phoneNumber: string;
      role: UserRole;
    },
    extraDetails: ExtraDetails = {}
  ): Promise<IUser> {
    const { email, phoneNumber } = userData;
  
    const existingUser = await User.findOne({ $or: [{ email }, { phoneNumber }] });
    if (existingUser) {
      throw new Error("L'email ou le numéro de téléphone est déjà utilisé");
    }
  
    const hashedPassword = await bcrypt.hash(userData.password, 10);
  
    const details = extraDetails.details || {};
    
    // Vérification de services
    if (details.services && (!Array.isArray(details.services) || !details.services.every(s => typeof s === 'string'))) {
      throw new Error("Le champ 'services' doit être un tableau de chaînes");
    }
  
    // Vérification de workingHours
    if (details.workingHours && !Array.isArray(details.workingHours)) {
      throw new Error("Le champ 'workingHours' doit être un tableau");
    }
  
    if (Array.isArray(details.workingHours)) {
      const validDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
      const isValidTime = (time: string) => /^([01]\d|2[0-3]):[0-5]\d$/.test(time);
  
      for (const slot of details.workingHours) {
        if (!slot.day || !slot.start || !slot.end) {
          throw new Error("Chaque horaire doit avoir 'day', 'start' et 'end'");
        }
        if (!validDays.includes(slot.day)) {
          throw new Error(`Jour invalide: ${slot.day}`);
        }
        if (!isValidTime(slot.start) || !isValidTime(slot.end)) {
          throw new Error(`Heure invalide pour ${slot.day}. Format attendu: HH:MM`);
        }
      }
    }
  
    const newUser = new User({
      ...userData,
      password: hashedPassword,
      profilePicture: extraDetails.profilePicture || '',
      MapsLocation: extraDetails.MapsLocation || '',
      description: extraDetails.description || '',
      details,
      reviews: extraDetails.reviews || [],
      rating: extraDetails.rating ?? 0,
      refreshToken: null,
    });
  
    await newUser.save();
    return newUser;
  }
  static async authenticateUser(username: string, password: string) {
    const user = await User.findOne({ username }).select("+password");
    if (!user) throw new Error("Utilisateur non trouvé");

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new Error("Identifiants invalides");

    const accessToken = this.generateAccessToken(user.id, user.role);
    const refreshToken = this.generateRefreshToken(user.id);

    user.refreshToken = refreshToken;
    await user.save();

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        role: user.role,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email
      }
    };
  }

  static async refreshAccessToken(refreshToken: string) {
    if (!refreshToken) throw new Error("Refresh token requis");

    const user = await User.findOne({ refreshToken });
    if (!user) throw new Error("Token invalide ou expiré");

    try {
      const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET || "refresh_secret") as { id: string };
      const newAccessToken = this.generateAccessToken(decoded.id, user.role);
      return { accessToken: newAccessToken };
    } catch (error) {
      throw new Error("Refresh token invalide");
    }
  }

  static async logoutUser(userId: string): Promise<void> {
    const user = await User.findById(userId);
    if (!user) throw new Error("Utilisateur non trouvé");

    user.refreshToken = null;
    await user.save();
  }

  private static generateAccessToken(userId: string, role: UserRole): string {
    return jwt.sign(
      { id: userId, role },
      process.env.JWT_SECRET || "secret",
      { expiresIn: "1h" }
    );
  }

  private static generateRefreshToken(userId: string): string {
    return jwt.sign(
      { id: userId },
      process.env.JWT_REFRESH_SECRET || "refresh_secret",
      { expiresIn: "7d" }
    );
  }

  static async getUserById(userId: string): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("ID utilisateur invalide");
    }
    return await User.findById(userId);
  }

  static async updateUser(userId: string, updateData: Partial<IUser>): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("ID utilisateur invalide");
    }

    if (updateData.email || updateData.phoneNumber) {
      const existingUser = await User.findOne({
        $or: [
          { email: updateData.email },
          { phoneNumber: updateData.phoneNumber }
        ],
        _id: { $ne: userId }
      });
      if (existingUser) {
        throw new Error("L'email ou le numéro de téléphone est déjà utilisé par un autre utilisateur");
      }
    }

    if (updateData.password) {
      updateData.password = await bcrypt.hash(updateData.password, 10);
    }

    return await User.findByIdAndUpdate(userId, updateData, {
      new: true,
      runValidators: true
    });
  }

  static async deleteUser(userId: string): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("ID utilisateur invalide");
    }
    return await User.findByIdAndDelete(userId);
  }

  static async getUsersByRole(role: UserRole): Promise<IUser[]> {
    return await User.find({ role });
  }

  static async getVeterinarians(filters: {
    rating?: number;
    MapsLocation?: string;
    page?: number;
    limit?: number;
    sort?: 'asc' | 'desc';
  } = {}): Promise<IUser[]> {
    const { rating, MapsLocation, page = 1, limit = 10, sort = 'desc' } = filters;
    const filter: any = { role: UserRole.VETERINAIRE };

    if (rating) {
      filter.rating = { $gte: rating };
    }

    if (MapsLocation) {
      filter.MapsLocation = { $regex: new RegExp(MapsLocation, 'i') };
    }

    const sortOrder = sort === 'asc' ? 1 : -1;

    return await User.find(filter)
      .select('-password -refreshToken')
      .sort({ rating: sortOrder })
      .skip((page - 1) * limit)
      .limit(limit);
  }

  static async searchVeterinarians(searchTerm?: string, services?: string): Promise<IUser[]> {
    const query: any = { role: UserRole.VETERINAIRE };

    if (searchTerm) {
      query.$or = [
        { firstName: new RegExp(searchTerm, 'i') },
        { lastName: new RegExp(searchTerm, 'i') },
        { 'details.services': new RegExp(searchTerm, 'i') }
      ];
    }

    if (services) {
      query['details.services'] = services;
    }

    return await User.find(query)
      .select('-password -refreshToken')
      .sort({ rating: -1, lastName: 1 });
  }
}
