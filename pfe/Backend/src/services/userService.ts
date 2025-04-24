import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import mongoose, { Document, Types } from "mongoose";
import User, { IUser, UserRole } from "../models/User";

//#region Type Definitions
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
  reviews?: Types.ObjectId[];
  rating?: number;
  address?: Address;
  isActive?: boolean;
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
  user: SafeUserInfo;
}

interface SafeUserInfo {
  id: string;
  role: UserRole;
  firstName: string;
  lastName: string;
  email: string;
  username: string;
}

interface LoginCredentials {
  username: string;
  password: string;
}

interface UserCreateData {
  firstName: string;
  lastName: string;
  username: string;
  email: string;
  password: string;
  phoneNumber: string;
  role: UserRole;
}
//#endregion

//#region Constants
const PASSWORD_MIN_LENGTH = 8;
const ACCESS_TOKEN_EXPIRATION = "15m";
const REFRESH_TOKEN_EXPIRATION = "7d";
const VETERINARIANS_PER_PAGE = 10;
const MAX_LOGIN_ATTEMPTS = 5;
const LOCK_TIME = 30 * 60 * 1000; // 30 minutes
const VALID_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] as const;

const ERROR_MESSAGES = {
  INVALID_INPUT: "Invalid input provided",
  INVALID_PASSWORD: `Password must contain at least ${PASSWORD_MIN_LENGTH} characters with uppercase, lowercase and numbers`,
  INVALID_EMAIL: "Invalid email format",
  INVALID_PHONE: "Invalid phone number format (8-15 digits required)",
  INVALID_SERVICES: "Services must be an array of strings",
  INVALID_EXPERIENCE: "Experience years must be between 0 and 100",
  INVALID_WORKING_HOURS: "Working hours must be an array with valid time slots",
  INVALID_TIME_SLOT: "Each time slot must have 'day', 'start' and 'end'",
  INVALID_DAY: (day: string) => `Invalid day: ${day}. Valid days: ${VALID_DAYS.join(', ')}`,
  INVALID_TIME_FORMAT: "Invalid time format. Expected HH:MM",
  INVALID_ADDRESS_FIELD: (field: string) => `Field ${field} must be a string`,
  USER_EXISTS: "An account with these details already exists",
  USER_NOT_FOUND: "User not found",
  ROLE_MODIFICATION: "Role modification is not allowed",
  DUPLICATE_FIELDS: "Phone number, username or email already in use by another account",
  INVALID_RATING: "Rating must be between 0 and 5",
  ACCOUNT_LOCKED: (minutes: number) => `Account locked. Try again in ${minutes} minutes`,
  INVALID_CREDENTIALS: "Invalid credentials",
  JWT_CONFIG_MISSING: "JWT configuration missing",
  INVALID_REFRESH_TOKEN: "Invalid or expired refresh token",
  VALIDATION_FAILED: "Validation failed",
  MISSING_REFRESH_TOKEN: "Refresh token is required",
  INVALID_USER_ID: "Invalid user ID format",
  INVALID_TOKEN: "Invalid token provided",
  INVALID_TOKEN_PAYLOAD: "Invalid token payload",
  TOKEN_REFRESH_FAILED: "Failed to refresh token",
  LOGOUT_FAILED: "Failed to logout user"
};
//#endregion

export class UserService {
  static getVeterinaireById: any;
//#region Authentication Methods
static async authenticateUser(credentials: LoginCredentials): Promise<AuthTokens> {
  const { username, password } = credentials;
  const normalized = username.trim().toLowerCase();

  console.log(`[auth] Tentative de connexion pour : ${normalized}`);

  // Rechercher l'utilisateur
  const user = await this.findActiveUser(normalized);
  console.log(`[auth] findActiveUser a renvoyé : ${user.username}`);

  // Comparaison du mot de passe
  console.log("[auth] mot de passe envoyé :", password);
  console.log("[auth] hash en base        :", user.password);
  const ok = await bcrypt.compare(password, user.password);
  console.log("[auth] bcrypt.compare →", ok);

  if (!ok) {
    console.warn(`[auth] Mot de passe incorrect pour ${normalized}`);
    throw new Error(ERROR_MESSAGES.INVALID_CREDENTIALS);
  }

  // Génération des tokens
  const tokens = await this.generateAndSaveTokens(user);
  console.log("[auth] Tokens générés");

  return { ...tokens, user: this.getUserSafeInfo(user) };
}



private static async generateAndSaveTokens(user: IUser): Promise<{ accessToken: string; refreshToken: string }> {
  const tokens = this.generateAuthTokens(user);
  await Promise.all([
    this.updateRefreshToken(user._id, tokens.refreshToken),
    this.resetSecurityFields(user._id)
  ]);
  return tokens;
}

static async refreshAccessToken(refreshToken: string): Promise<{ accessToken: string }> {
  if (!refreshToken?.trim()) {
    throw new Error(ERROR_MESSAGES.INVALID_TOKEN);
  }

  try {
    const payload = this.verifyRefreshToken(refreshToken);
    const user = await this.findUserByRefreshToken(payload.id, refreshToken);
    return {
      accessToken: this.generateAccessToken(this.getUserSafeInfo(user))
    };
  } catch (error) {
    console.error('[auth] Échec de renouvellement de token:', error);
    throw new Error(ERROR_MESSAGES.TOKEN_REFRESH_FAILED);
  }
}

static isTokenValid(token: string): boolean {
  try {
    jwt.verify(token, process.env.JWT_ACCESS_SECRET!);
    return true;
  } catch {
    return false;
  }
}

private static verifyRefreshToken(token: string): { id: string } {
  this.validateJwtConfiguration();

  try {
    return jwt.verify(token.trim(), process.env.JWT_REFRESH_SECRET!) as { id: string };
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new Error("Refresh token expired");
    }
    throw new Error(ERROR_MESSAGES.INVALID_REFRESH_TOKEN);
  }
}

static async logout(userId: string): Promise<void> {
  if (!Types.ObjectId.isValid(userId)) {
    throw new Error(ERROR_MESSAGES.INVALID_USER_ID);
  }

  try {
    const result = await User.findByIdAndUpdate(
      new Types.ObjectId(userId),
      { $set: { refreshToken: null } },
      { new: true }
    );

    if (!result) {
      throw new Error(ERROR_MESSAGES.USER_NOT_FOUND);
    }
  } catch (error) {
    console.error(`[auth] Échec du logout pour ${userId}:`, error);
    throw new Error(ERROR_MESSAGES.LOGOUT_FAILED);
  }
}
//#endregion

  //#region User CRUD Operations
  static async createUser(
    userData: UserCreateData,
    extraDetails: ExtraDetails = {}
  ): Promise<IUser> {
    this.validateUserData(userData, extraDetails);
    await this.checkDuplicateUser(userData);

    const hashedPassword = await this.hashPassword(userData.password);
    const newUser = await this.saveUser(userData, extraDetails, hashedPassword);

    return newUser.toObject();
  }

  static async getUserById(userId: string): Promise<IUser> {
    this.validateUserId(userId);
    
    const user = await User.findById(new Types.ObjectId(userId))
      .select("-password -refreshToken -loginAttempts -lockUntil");

    if (!user) {
      throw new Error(ERROR_MESSAGES.USER_NOT_FOUND);
    }
    return user.toObject();
  }

  static async updateUser(
    userId: string, 
    updateData: Partial<IUser>
  ): Promise<IUser> {
    this.validateUserId(userId);
    this.validateUpdateData(updateData);

    if (updateData.phoneNumber || updateData.username || updateData.email) {
      await this.checkUniqueFields(userId, updateData);
    }

    if (updateData.password) {
      updateData.password = await this.hashPassword(updateData.password);
    }

    const updatedUser = await User.findByIdAndUpdate(
      new Types.ObjectId(userId),
      updateData,
      { 
        new: true, 
        runValidators: true,
        select: "-password -refreshToken -loginAttempts -lockUntil" 
      }
    );

    if (!updatedUser) {
      throw new Error(ERROR_MESSAGES.USER_NOT_FOUND);
    }

    return updatedUser.toObject();
  }

  static async deleteUser(userId: string): Promise<IUser> {
    this.validateUserId(userId);
    
    const deletedUser = await User.findByIdAndUpdate(
      new Types.ObjectId(userId),
      { isActive: false },
      { new: true }
    ).select("-password -refreshToken");

    if (!deletedUser) {
      throw new Error(ERROR_MESSAGES.USER_NOT_FOUND);
    }

    return deletedUser.toObject();
  }
  //#endregion

  //#region Private Helper Methods
// src/services/userService.ts

// src/services/userService.ts

private static async findActiveUser(username: string): Promise<IUser & { password: string }> {
  const normalized = username.toLowerCase();

  // Recherche de l’utilisateur (quel que soit isActive)
  console.log("[findActiveUser] Recherche par username seulement :", normalized);
  const user = await User.findOne({ username: normalized })
    .select('+password +refreshToken +loginAttempts +lockUntil +lastFailedAttempt +isActive')
    .collation({ locale: 'en', strength: 2 });

  if (!user) {
    console.warn("[findActiveUser] Aucun utilisateur trouvé pour :", normalized);
    throw new Error(ERROR_MESSAGES.INVALID_CREDENTIALS);
  }

  console.log("[findActiveUser] Utilisateur trouvé :", {
    _id: user._id.toString(),
    username: user.username,
    isActive: user.isActive,
    passwordHash: user.password
  });

  // Vérification du statut actif
  if (!user.isActive) {
    console.warn("[findActiveUser] Utilisateur trouvé mais inactif :", normalized);
    throw new Error(ERROR_MESSAGES.INVALID_CREDENTIALS);
  }

  // Vérification du verrouillage
  this.checkAccountLockStatus(user);

  return user;
}


  private static checkAccountLockStatus(user: IUser & { lockUntil?: Date | number | null }): void {
    if (!user.lockUntil) return;
    
    const lockUntilDate = typeof user.lockUntil === 'number' 
      ? new Date(user.lockUntil)
      : user.lockUntil;
      
    if (lockUntilDate && new Date(lockUntilDate) > new Date()) {
      const remainingTime = Math.ceil((new Date(lockUntilDate).getTime() - Date.now()) / (60 * 1000));
      throw new Error(ERROR_MESSAGES.ACCOUNT_LOCKED(remainingTime));
    }
  }

  private static async verifyCredentials(
    user: IUser & { password: string }, 
    inputPassword: string
  ): Promise<void> {
    const isMatch = await bcrypt.compare(inputPassword.trim(), user.password);
    if (!isMatch) {
      throw new Error(ERROR_MESSAGES.INVALID_CREDENTIALS);
    }
  }

  private static async handleFailedLogin(username: string): Promise<void> {
    const user = await User.findOne({ username });
    if (!user) return;
  
    const updates: any = { $inc: { loginAttempts: 1 } };
  
    if ((user.loginAttempts || 0) + 1 >= MAX_LOGIN_ATTEMPTS) {
      updates.$set = {
        lockUntil: Date.now() + LOCK_TIME,
        lastFailedAttempt: new Date()
      };
    }
  
    await User.updateOne({ username }, updates);
  }
  
  private static async resetSecurityFields(userId: Types.ObjectId): Promise<void> {
    await User.findByIdAndUpdate(userId, { 
      $set: { 
        loginAttempts: 0, 
        lockUntil: null,
        lastLogin: new Date() 
      } 
    });
  }

  private static getUserSafeInfo(user: IUser): SafeUserInfo {
    return {
      id: user._id.toString(),
      role: user.role,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      username: user.username
    };
  }

  private static generateAuthTokens(user: IUser): { accessToken: string; refreshToken: string } {
    this.validateJwtConfiguration();
    
    const userInfo = this.getUserSafeInfo(user);
    
    return {
      accessToken: jwt.sign(
        { ...userInfo },
        process.env.JWT_ACCESS_SECRET!,
        { expiresIn: ACCESS_TOKEN_EXPIRATION }
      ),
      refreshToken: jwt.sign(
        { id: user._id.toString() },
        process.env.JWT_REFRESH_SECRET!,
        { expiresIn: REFRESH_TOKEN_EXPIRATION }
      )
    };
  }

  private static validateJwtConfiguration(): void {
    if (!process.env.JWT_ACCESS_SECRET || !process.env.JWT_REFRESH_SECRET) {
      throw new Error(ERROR_MESSAGES.JWT_CONFIG_MISSING);
    }
  }

  private static async updateRefreshToken(userId: Types.ObjectId, refreshToken: string): Promise<void> {
    await User.findByIdAndUpdate(userId, { 
      $set: { 
        refreshToken,
        lastLogin: new Date() 
      } 
    });
  }

  private static async findUserByRefreshToken(userId: string, refreshToken: string): Promise<IUser> {
    const user = await User.findOne({
      _id: new Types.ObjectId(userId),
      refreshToken: refreshToken.trim(),
      isActive: true
    });

    if (!user) {
      throw new Error(ERROR_MESSAGES.INVALID_REFRESH_TOKEN);
    }
    return user;
  }

  private static generateAccessToken(userInfo: SafeUserInfo): string {
    this.validateJwtConfiguration();
    return jwt.sign(
      { ...userInfo },
      process.env.JWT_ACCESS_SECRET!,
      { expiresIn: ACCESS_TOKEN_EXPIRATION }
    );
  }

  private static validateUserData(
    userData: UserCreateData,
    extraDetails: ExtraDetails
  ): void {
    this.validateEmail(userData.email);
    this.validatePhoneNumber(userData.phoneNumber);
    this.validatePassword(userData.password);
    this.validateUserDetails(extraDetails.details);
    this.validateAddress(extraDetails.address);
  }

  private static async checkDuplicateUser(userData: UserCreateData): Promise<void> {
    const existingUser = await User.findOne({
      $or: [
        { email: userData.email.toLowerCase() },
        { phoneNumber: userData.phoneNumber },
        { username: userData.username.toLowerCase() }
      ]
    });

    if (existingUser) {
      throw new Error(ERROR_MESSAGES.USER_EXISTS);
    }
  }

  private static async saveUser(
    userData: UserCreateData,
    extraDetails: ExtraDetails,
    hashedPassword: string
  ): Promise<IUser & Document> {
    const newUser = new User({
      ...userData,
      email: userData.email.toLowerCase(),
      username: userData.username.toLowerCase(),
      password: hashedPassword,
      ...extraDetails,
      refreshToken: null,
      isActive: true,
      loginAttempts: 0
    });

    await newUser.save();
    return newUser;
  }

  private static validateUpdateData(updateData: Partial<IUser>): void {
    if ('role' in updateData) {
      throw new Error(ERROR_MESSAGES.ROLE_MODIFICATION);
    }
  }

  private static async checkUniqueFields(userId: string, updateData: Partial<IUser>): Promise<void> {
    const query = {
      _id: { $ne: new Types.ObjectId(userId) },
      $or: [] as any[]
    };

    if (updateData.phoneNumber) {
      this.validatePhoneNumber(updateData.phoneNumber);
      query.$or.push({ phoneNumber: updateData.phoneNumber });
    }

    if (updateData.username) {
      query.$or.push({ username: updateData.username.toLowerCase() });
    }

    if (updateData.email) {
      this.validateEmail(updateData.email);
      query.$or.push({ email: updateData.email.toLowerCase() });
    }

    if (query.$or.length > 0) {
      const existingUser = await User.findOne(query);
      if (existingUser) {
        throw new Error(ERROR_MESSAGES.DUPLICATE_FIELDS);
      }
    }
  }

  private static async hashPassword(password: string): Promise<string> {
    this.validatePassword(password);
    return bcrypt.hash(password, 12);
  }

  private static validatePassword(password: string): void {
    if (!password || password.length < PASSWORD_MIN_LENGTH) {
      throw new Error(ERROR_MESSAGES.INVALID_PASSWORD);
    }
    if (!/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/[0-9]/.test(password)) {
      throw new Error(ERROR_MESSAGES.INVALID_PASSWORD);
    }
  }

  private static validateEmail(email: string): void {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new Error(ERROR_MESSAGES.INVALID_EMAIL);
    }
  }

  private static validatePhoneNumber(phone: string): void {
    const phoneRegex = /^[0-9]{8,15}$/;
    if (!phoneRegex.test(phone)) {
      throw new Error(ERROR_MESSAGES.INVALID_PHONE);
    }
  }

  private static validateUserDetails(details?: UserDetails): void {
    if (!details) return;

    if (details.services && !this.isStringArray(details.services)) {
      throw new Error(ERROR_MESSAGES.INVALID_SERVICES);
    }

    if (details.workingHours) {
      this.validateWorkingHours(details.workingHours);
    }

    if (details.experienceYears !== undefined && 
        (details.experienceYears < 0 || details.experienceYears > 100)) {
      throw new Error(ERROR_MESSAGES.INVALID_EXPERIENCE);
    }
  }

  private static validateWorkingHours(workingHours: WorkingHours[]): void {
    if (!Array.isArray(workingHours)) {
      throw new Error(ERROR_MESSAGES.INVALID_WORKING_HOURS);
    }

    for (const slot of workingHours) {
      if (!slot.day || !slot.start || !slot.end) {
        throw new Error(ERROR_MESSAGES.INVALID_TIME_SLOT);
      }
      if (!VALID_DAYS.includes(slot.day as typeof VALID_DAYS[number])) {
        throw new Error(ERROR_MESSAGES.INVALID_DAY(slot.day));
      }
      if (!this.isValidTimeFormat(slot.start) || !this.isValidTimeFormat(slot.end)) {
        throw new Error(ERROR_MESSAGES.INVALID_TIME_FORMAT);
      }
    }
  }

  private static validateAddress(address?: Address): void {
    if (!address) return;
    
    Object.entries(address).forEach(([field, value]) => {
      if (value !== undefined && typeof value !== 'string') {
        throw new Error(ERROR_MESSAGES.INVALID_ADDRESS_FIELD(field));
      }
    });
  }

  private static isStringArray(arr: any[]): boolean {
    return Array.isArray(arr) && arr.every(item => typeof item === 'string');
  }

  private static isValidTimeFormat(time: string): boolean {
    return /^([01]\d|2[0-3]):[0-5]\d$/.test(time);
  }

  private static validateUserId(userId: string): void {
    if (!Types.ObjectId.isValid(userId)) {
      throw new Error(ERROR_MESSAGES.INVALID_USER_ID);
    }
  }
  //#endregion
}