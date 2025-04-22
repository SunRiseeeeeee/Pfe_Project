import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User, { IUser, UserRole } from "../models/User";
import mongoose from "mongoose";

interface Address {
  street?: string;
  city?: string;
  state?: string;
  country?: string;
  postalCode?: string;
}

interface WorkingHours {
  day: string;
  start: string;
  end: string;
}

interface UserDetails {
  services?: string[];
  workingHours?: WorkingHours[];
  specialization?: string;
  experienceYears?: number;
}

interface ExtraDetails {
  profilePicture?: string;
  mapsLocation?: string;
  description?: string;
  details?: UserDetails;
  reviews?: mongoose.Types.ObjectId[];
  rating?: number;
  address?: Address;
}

interface Filters {
  rating?: number;
  location?: string;
  services?: string[];
  page?: number;
  limit?: number;
  sort?: 'asc' | 'desc';
  specialization?: string;
}

interface VeterinarianResult {
  veterinarians: IUser[];
  totalCount: number;
  page: number;
  limit: number;
  totalPages: number;
}

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    role: UserRole;
    firstName: string;
    lastName: string;
    email: string;
    username: string;
  };
}

export class UserService {
  private static validatePassword(password: string): void {
    if (password.length < 8) {
      throw new Error("Password must be at least 8 characters long");
    }
  }

  private static validateEmail(email: string): void {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new Error("Invalid email format");
    }
  }

  static validatePhoneNumber(phone: string): void {
    const phoneRegex = /^[0-9]{8}$/; // Exemple : format tunisien à 8 chiffres
    if (!phoneRegex.test(phone)) {
      throw new Error("Invalid phone number format");
    }
  }
  

  private static validateUserDetails(details: UserDetails): void {
    if (details.services && (!Array.isArray(details.services) || !details.services.every(s => typeof s === 'string'))) {
      throw new Error("Services must be an array of strings");
    }

    if (details.workingHours) {
      if (!Array.isArray(details.workingHours)) {
        throw new Error("Working hours must be an array");
      }

      const validDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
      const isValidTime = (time: string) => /^([01]\d|2[0-3]):[0-5]\d$/.test(time);

      for (const slot of details.workingHours) {
        if (!slot.day || !slot.start || !slot.end) {
          throw new Error("Each working hour slot must have 'day', 'start' and 'end'");
        }
        if (!validDays.includes(slot.day)) {
          throw new Error(`Invalid day: ${slot.day}. Valid days are: ${validDays.join(', ')}`);
        }
        if (!isValidTime(slot.start) || !isValidTime(slot.end)) {
          throw new Error(`Invalid time format for ${slot.day}. Expected format: HH:MM`);
        }
      }
    }
  }

  private static validateAddress(address: Address): void {
    if (address) {
      const { street, city, state, country, postalCode } = address;
      const addressFields = [street, city, state, country, postalCode];
      
      if (addressFields.some(field => field && typeof field !== 'string')) {
        throw new Error("All address fields must be strings");
      }
    }
  }

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
    const { email, phoneNumber, password } = userData;

    // Validate input
    this.validateEmail(email);
    this.validatePhoneNumber(phoneNumber);
    this.validatePassword(password);
    
    if (extraDetails.details) {
      this.validateUserDetails(extraDetails.details);
    }
    
    if (extraDetails.address) {
      this.validateAddress(extraDetails.address);
    }

    // Check for existing user
    const existingUser = await User.findOne({ $or: [{ email }, { phoneNumber }, { username: userData.username }] });
    if (existingUser) {
      throw new Error("Email, phone number or username already in use");
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    // Create new user
    const newUser = new User({
      ...userData,
      password: hashedPassword,
      profilePicture: extraDetails.profilePicture || undefined,
      mapsLocation: extraDetails.mapsLocation || undefined,
      description: extraDetails.description || undefined,
      details: extraDetails.details || undefined,
      address: extraDetails.address || undefined,
      reviews: extraDetails.reviews || [],
      rating: extraDetails.rating ?? 0,
      refreshToken: null,
    });

    await newUser.save();
    return newUser;
  }

  static async authenticateUser(username: string, password: string): Promise<AuthTokens> {
    if (!username || !password) {
      throw new Error("Username and password are required");
    }
  
    try {
      // Recherche de l'utilisateur par 'username', incluant le mot de passe pour la vérification
      const user = await User.findOne({ username }).select("+password");
      
      // Vérification de l'existence de l'utilisateur
      if (!user) {
        throw new Error("Invalid credentials");  // Utilisateur non trouvé
      }
  
      // Comparaison du mot de passe hashé
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        throw new Error("Invalid credentials");  // Le mot de passe est incorrect
      }
  
      // Génération des tokens JWT
      const accessToken = this.generateAccessToken(user.id, user.role);
      const refreshToken = this.generateRefreshToken(user.id);
  
      // Sauvegarder le refreshToken dans l'utilisateur (optionnel, si nécessaire)
      user.refreshToken = refreshToken;
      await user.save();
  
      // Retourner les tokens et les informations de l'utilisateur, incluant l'email
      return {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          role: user.role,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,  // Ajout de l'email
          username: user.username
        }
      };
    } catch (error) {
      // Gestion des erreurs
      console.error("Erreur d'authentification :", error);  // Log d'erreur pour faciliter le débogage
      throw new Error("Authentication failed");  // Message générique d'erreur
    }
  }
  
  

  static async refreshAccessToken(refreshToken: string): Promise<{ accessToken: string }> {
    if (!refreshToken) {
      throw new Error("Refresh token is required");
    }

    const user = await User.findOne({ refreshToken });
    if (!user) {
      throw new Error("Invalid or expired refresh token");
    }

    try {
      const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET || "refresh_secret") as { id: string };
      const newAccessToken = this.generateAccessToken(decoded.id, user.role);
      return { accessToken: newAccessToken };
    } catch (error) {
      throw new Error("Invalid refresh token");
    }
  }

  static async logoutUser(userId: string): Promise<void> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("ID utilisateur invalide");
    }
  
    const user = await User.findById(userId);
    if (!user) {
      throw new Error("Utilisateur non trouvé");
    }
  
    user.refreshToken = null;
    await user.save();
  }
  

  private static generateAccessToken(userId: string, role: UserRole): string {
    if (!process.env.JWT_SECRET) {
      throw new Error("JWT_SECRET environment variable is not set");
    }

    return jwt.sign(
      { id: userId, role },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );
  }

  private static generateRefreshToken(userId: string): string {
    if (!process.env.JWT_REFRESH_SECRET) {
      throw new Error("JWT_REFRESH_SECRET environment variable is not set");
    }

    return jwt.sign(
      { id: userId },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: "7d" }
    );
  }

  static async getUserById(userId: string): Promise<IUser> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("Invalid user ID");
    }

    const user = await User.findById(userId);
    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  static async updateUser(userId: string, updateData: Partial<IUser>): Promise<IUser> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("Invalid user ID");
    }
  
    // ❌ Interdire explicitement la modification de l'email ou du rôle
    if ('email' in updateData || 'role' in updateData) {
      throw new Error("La modification de l'email ou du rôle est interdite");
    }
  
    // ✅ Vérification doublons (email déjà interdit)
    if (updateData.phoneNumber || updateData.username) {
      const query: any = { _id: { $ne: userId } };
      const orConditions = [];
  
      if (updateData.phoneNumber) {
        this.validatePhoneNumber(updateData.phoneNumber);
        orConditions.push({ phoneNumber: updateData.phoneNumber });
      }
  
      if (updateData.username) {
        orConditions.push({ username: updateData.username });
      }
  
      query.$or = orConditions;
  
      const existingUser = await User.findOne(query);
      if (existingUser) {
        throw new Error("Phone number or username already in use by another user");
      }
    }
  
    // 🔒 Hash du mot de passe si nécessaire
    if (updateData.password) {
      this.validatePassword(updateData.password);
      updateData.password = await bcrypt.hash(updateData.password, 12);
    }
  
    // 🛂 Validation des détails supplémentaires
    if (updateData.details) {
      this.validateUserDetails(updateData.details as UserDetails);
    }
  
    if (updateData.address) {
      this.validateAddress(updateData.address as Address);
    }
  
    // 🚀 Mise à jour
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      updateData,
      { new: true, runValidators: true }
    );
  
    if (!updatedUser) {
      throw new Error("User not found");
    }
  
    return updatedUser;
  }
  
  

  static async deleteUser(userId: string): Promise<IUser> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("Invalid user ID");
    }

    const deletedUser = await User.findByIdAndDelete(userId);
    if (!deletedUser) {
      throw new Error("User not found");
    }

    return deletedUser;
  }

  static async getUsersByRole(role: UserRole, page: number = 1, limit: number = 10): Promise<{ users: IUser[]; total: number }> {
    const skip = (page - 1) * limit;
    const [users, total] = await Promise.all([
      User.find({ role }).skip(skip).limit(limit),
      User.countDocuments({ role })
    ]);

    return { users, total };
  }

  static async getVeterinarians(filters: Filters = {}): Promise<VeterinarianResult> {
    const {
      rating,
      location,
      services,
      specialization,
      page = 1,
      limit = 10,
      sort = 'desc',
    } = filters;

    const query: any = { role: UserRole.VETERINAIRE };

    // Rating filter
    if (typeof rating === 'number' && !isNaN(rating) && rating >= 0 && rating <= 5) {
      query.rating = { $gte: rating };
    }

    // Location filter
    if (location) {
      const regex = new RegExp(location, 'i');
      query.$or = [
        { 'address.street': { $regex: regex } },
        { 'address.city': { $regex: regex } },
        { 'address.state': { $regex: regex } },
        { 'address.country': { $regex: regex } },
        { 'address.postalCode': { $regex: regex } },
      ];
    }

    // Services filter
    if (services && services.length > 0) {
      query['details.services'] = { $all: services };
    }

    // Specialization filter
    if (specialization) {
      query['details.specialization'] = specialization;
    }

    // Pagination
    const pageNumber = Math.max(1, parseInt(page.toString(), 10));
    const limitNumber = Math.min(100, Math.max(1, parseInt(limit.toString(), 10)));
    const skip = (pageNumber - 1) * limitNumber;
    const sortOrder = sort === 'asc' ? 1 : -1;

    const [veterinarians, totalCount] = await Promise.all([
      User.find(query)
        .select('-password -refreshToken')
        .sort({ rating: sortOrder, lastName: 1 })
        .skip(skip)
        .limit(limitNumber)
        .lean(),
      User.countDocuments(query),
    ]);

    return {
      veterinarians: veterinarians as IUser[],
      totalCount,
      page: pageNumber,
      limit: limitNumber,
      totalPages: Math.ceil(totalCount / limitNumber),
    };
  }
  static async getVeterinaireById(userId: string): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      throw new Error("Invalid user ID");
    }
  
    const user = await User.findOne({ _id: userId, role: UserRole.VETERINAIRE }).select("-password -refreshToken");
  
    return user;
  }
  
}