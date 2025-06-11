import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { JwtPayload } from "../middlewares/authMiddleware";
import mongoose, { Document, Types } from "mongoose";
import User, { IUser, UserRole } from "../models/User";
import nodemailer from 'nodemailer';
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
  pauseStart?: string;
  pauseEnd?: string;
}

interface UserDetails {
  services?: string[];
  workingHours?: WorkingHours[];
  specialization?: string;
  experienceYears?: number;
}

interface ExtraDetails {
 
  
  mapsLocation?: string;
  description?: string;
  details?: UserDetails;
  reviews?: Types.ObjectId[];
  rating?: number;
  address?: Address;
  isActive?: boolean;
}
export interface UserCreateData {
  firstName: string;
  lastName: string;
  username: string;
  email: string;
  password: string;
  phoneNumber: string;
  role: UserRole;
  profilePicture?: string;
  mapsLocation?: string;        // <-- Ajoute ceci
  description?: string;         // <-- Et ça
  address?: Address;            // <-- Et ça si besoin
  details?: UserDetails;        // <-- Et ça aussi
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
  phoneNumber: string;
  profilePicture?: string;
  address?: Address;
}

interface LoginCredentials {
  username: string;
  password: string;
}



interface TokenResponse {
  accessToken: string;
  refreshToken: string;
}
//#endregion

//#region Constants
const PASSWORD_MIN_LENGTH = 8;
const ACCESS_TOKEN_EXPIRATION = "15m";
const REFRESH_TOKEN_EXPIRATION = "7d";
const MAX_LOGIN_ATTEMPTS = 5;
const LOCK_TIME = 30 * 60 * 1000; // 30 minutes
const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;
const VALID_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] as const;

const ErrorMessages = {
  INVALID_CREDENTIALS: "Invalid username or password",
  ACCOUNT_LOCKED: (minutes: number) => `Account locked. Try again in ${minutes} minutes`,
  INVALID_REFRESH_TOKEN: "Invalid or expired refresh token",
  USER_NOT_FOUND: "User not found",
  USER_EXISTS: "User already exists with this email, username or phone number",
  INVALID_PASSWORD: "Password must contain at least 8 characters including uppercase, lowercase and numbers",
  INVALID_EMAIL: "Invalid email format",
  INVALID_PHONE: "Phone number must be 8-15 digits",
  DUPLICATE_FIELDS: "Another user already exists with these details",
  ROLE_MODIFICATION: "Role modification is not allowed",
  JWT_CONFIG_MISSING: "JWT configuration missing",
  INVALID_USER_ID: "Invalid user ID format",
  ACCOUNT_INACTIVE: "Account is inactive"
};
//#endregion

export class AuthService {
  //#region Authentication
  static async forgetPassword(email: string): Promise<void> {
    if (!email) {
      throw new Error("Email is required");
    }

    // On récupère aussi les champs resetPasswordCode & resetPasswordExpires (select: false par défaut)
    const user = await User
      .findOne({ email: email.toLowerCase(), isActive: true })
      .select("+resetPasswordCode +resetPasswordExpires") as IUser | null;

    if (!user) {
      throw new Error("No active account found with this email");
    }

    // Générer un code de vérification à 6 chiffres
    const code = Math.floor(100000 + Math.random() * 900000).toString();

    // Ajouter une date d'expiration (15 minutes)
    const expiration = new Date(Date.now() + 15 * 60 * 1000);

    // Sauvegarder le code et son expiration dans la base
    user.resetPasswordCode = code;
    user.resetPasswordExpires = expiration;
    await user.save();

    // Configurer le transporteur SMTP (exemple avec Gmail)
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.SMTP_USER!,
        pass: process.env.SMTP_PASS!,
      },
    });

    // Contenu de l'email
    const mailOptions = {
      from: process.env.SMTP_USER!,
      to: user.email,
      subject: "Code de réinitialisation du mot de passe",
      text: `Bonjour ${user.firstName},\n\nVotre code de réinitialisation est : ${code}\n\nIl expire dans 15 minutes.`,
    };

    // Envoi de l'email
    await transporter.sendMail(mailOptions);
  }
  static async authenticate(credentials: LoginCredentials): Promise<AuthTokens> {
    try {
      const { username, password } = credentials;
      
      if (!username || !password) {
        throw new Error(ErrorMessages.INVALID_CREDENTIALS);
      }

      const user = await this.getActiveUser(username);
      await this.verifyPassword(user, password);
      
      const tokens = await this.generateTokens(user);
      return {
        ...tokens,
        user: this.getSafeUserInfo(user)
      };
    } catch (error) {
      console.error('Authentication failed:', error);
      throw error;
    }
  }

  private static async getActiveUser(username: string): Promise<IUser & { password: string }> {
    const user = await User.findOne({ username: username.toLowerCase() })
      .select('+password +refreshToken +loginAttempts +lockUntil +isActive')
      .orFail(new Error(ErrorMessages.INVALID_CREDENTIALS));

    if (!user.isActive) {
      throw new Error(ErrorMessages.ACCOUNT_INACTIVE);
    }

    this.checkAccountLock(user);
    return user;
  }
  private static async verifyPassword(user: IUser & { password: string }, password: string): Promise<void> {
    const isMatch = await bcrypt.compare(password, user.password); 
    if (!isMatch) {
      await this.handleFailedLogin(user.username);
      throw new Error(ErrorMessages.INVALID_CREDENTIALS);
    }
  }
  private static checkAccountLock(user: IUser & { lockUntil?: Date | number | null }): void {
    if (!user.lockUntil) return;
    
    const lockUntil = typeof user.lockUntil === 'number' 
      ? new Date(user.lockUntil) 
      : user.lockUntil;

    if (lockUntil > new Date()) {
      const minutes = Math.ceil((lockUntil.getTime() - Date.now()) / (60 * 1000));
      throw new Error(ErrorMessages.ACCOUNT_LOCKED(minutes));
    }
  }

  private static async handleFailedLogin(username: string): Promise<void> {
    await User.updateOne(
      { username },
      { 
        $inc: { loginAttempts: 1 },
        $set: { lastFailedAttempt: new Date() }
      }
    );

    const user = await User.findOne({ username });
    if (user && (user.loginAttempts || 0) >= MAX_LOGIN_ATTEMPTS) {
      await User.updateOne(
        { username },
        { $set: { lockUntil: Date.now() + LOCK_TIME } }
      );
    }
  }
  //#endregion

  //#region Token Management
  public static async generateTokens(user: IUser): Promise<TokenResponse> {
    const tokens = this.createTokens(user);
    await this.saveRefreshToken(user._id, tokens.refreshToken);
    await this.resetSecurityFields(user._id);
    return tokens;
  }
  private static createTokens(user: IUser): TokenResponse {
    this.validateJwtConfig();
  
    // Vérifier que user et user._id existent
    if (!user || !user._id) {
      throw new Error("Invalid user object: missing _id");
    }
    const commonPayload: JwtPayload = {
      id: user._id.toString(),
      role: user.role,
      firstName: user.firstName,
      lastName: user.lastName,
      username: user.username,
      phoneNumber: user.phoneNumber,
      profilePicture: user.profilePicture,
      address: user.address,
      iat: Math.floor(Date.now() / 1000),
      ...(user.role === UserRole.SECRETAIRE && user.veterinaireId && { veterinaireId: user.veterinaireId.toString() }),
    };
    const accessToken = jwt.sign(commonPayload, process.env.JWT_SECRET!, {
      expiresIn: ACCESS_TOKEN_EXPIRATION,
    });
  
    const refreshToken = jwt.sign(commonPayload, process.env.JWT_REFRESH_SECRET!, {
      expiresIn: REFRESH_TOKEN_EXPIRATION,
    });
  
    return { accessToken, refreshToken };
  }

  static async refreshToken(refreshToken: string): Promise<TokenResponse> {
    if (!refreshToken?.trim()) {
      throw new Error("Refresh token is required");
    }
  
    try {
      // Verify the token first
      const decoded = jwt.verify(
        refreshToken.trim(),
        process.env.JWT_REFRESH_SECRET!
      ) as JwtPayload;
  
      // Then find the user with this token
      const user = await User.findOne({
        _id: new Types.ObjectId(decoded.id),
        refreshToken: refreshToken.trim()
      });
  
      if (!user) {
        throw new Error("Invalid refresh token");
      }
  
      // Generate new tokens
      return this.createTokens(user);
    } catch (error) {
      console.error('Refresh token error:', error);
      throw new Error("Invalid or expired refresh token");
    }
  }
  private static verifyToken(token: string, secret: string): JwtPayload {
    try {
      return jwt.verify(token.trim(), secret) as JwtPayload;
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new Error("Token expired");
      }
      throw new Error(ErrorMessages.INVALID_REFRESH_TOKEN);
    }
  }
  private static async getUserByRefreshToken(userId: string, refreshToken: string): Promise<IUser> {
    if (!Types.ObjectId.isValid(userId)) {
      throw new Error(ErrorMessages.INVALID_USER_ID);
    }
    return await User.findOne({
      _id: new Types.ObjectId(userId),
      refreshToken: refreshToken.trim(),
      isActive: true
    }).orFail(new Error(ErrorMessages.INVALID_REFRESH_TOKEN));
  }
  static async logout(userId: string): Promise<void> {
    if (!Types.ObjectId.isValid(userId)) {
      throw new Error(ErrorMessages.INVALID_USER_ID);
    }

    await User.findByIdAndUpdate(
      new Types.ObjectId(userId),
      { $set: { refreshToken: null } }
    ).orFail(new Error(ErrorMessages.USER_NOT_FOUND));
  }
  //#endregion
  //#region Helpers
  private static getSafeUserInfo(user: IUser): SafeUserInfo {
    return {
      id: user._id.toString(),
      role: user.role,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      username: user.username,
      phoneNumber: user.phoneNumber,
      profilePicture: user.profilePicture,
      address: user.address
    };
  }
  private static validateJwtConfig(): void {
    if (!process.env.JWT_SECRET || !process.env.JWT_REFRESH_SECRET) {
      throw new Error(ErrorMessages.JWT_CONFIG_MISSING);
    }
  }
  private static async saveRefreshToken(userId: Types.ObjectId, refreshToken: string): Promise<void> {
    await User.findByIdAndUpdate(userId, { 
      $set: { 
        refreshToken,
        lastLogin: new Date() 
      } 
    });
  }
  private static async resetSecurityFields(userId: Types.ObjectId): Promise<void> {
    await User.findByIdAndUpdate(userId, { 
      $set: { 
        loginAttempts: 0, 
        lockUntil: null
      } 
    });
  }
  //#endregion
}
export class UserService {
  //#region Authentication Methods
  static async authenticateUser(credentials: LoginCredentials): Promise<AuthTokens> {
    return AuthService.authenticate(credentials);
  }
  static async refreshAccessToken(refreshToken: string): Promise<TokenResponse> {
    return AuthService.refreshToken(refreshToken);
  }
  static async logout(userId: string): Promise<void> {
    return AuthService.logout(userId);
  }
  //#endregion
// Modifiez la méthode createUser comme suit :
static async createUser(userData: UserCreateData, extraDetails: ExtraDetails = {}): Promise<IUser> {
  try {
    // 1. Envoi des informations par email avant le hashage
    await this.sendUserCredentialsByEmail(userData);

    // 2. Hashage du mot de passe
    const hashedPassword = await this.hashPassword(userData.password);

    // 3. Création et sauvegarde du document
    const newUser = new User({
      ...userData,
      ...extraDetails,
      password: hashedPassword,
      isActive: true,
    });

    const savedUser = await newUser.save();
    console.log("Saved user:", savedUser); // Log pour débogage

    // Retourner directement savedUser sans toObject
    return savedUser as IUser;
  } catch (error) {
    console.error("Erreur création utilisateur:", error);
    throw error;
  }
}

// Ajoutez cette nouvelle méthode pour l'envoi d'email

private static async sendUserCredentialsByEmail(userData: UserCreateData): Promise<void> {
  // Valider le format de l'email
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(userData.email)) {
    console.error(`Invalid email format: ${userData.email}`);
    throw new Error("Invalid email format");
  }

  // Supprimer les espaces éventuels et normaliser
  const recipientEmail = userData.email.trim().toLowerCase();

  // Vérifier que les variables d'environnement sont définies
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    console.error("Missing email configuration: EMAIL_USER or EMAIL_PASS not set");
    throw new Error("Email configuration missing");
  }

  // Configurer le transporteur Nodemailer
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  // Configurer les options de l'email
  const mailOptions = {
    from: `"PFE Project" <${process.env.EMAIL_USER}>`, // Nom d'expéditeur personnalisé
    to: recipientEmail,
    subject: "Vos identifiants de connexion",
    text: `Bonjour ${userData.firstName},\n\n
Votre compte a été créé avec succès. Voici vos informations de connexion :\n
- Prénom: ${userData.firstName}\n
- Nom: ${userData.lastName}\n
- Nom d'utilisateur: ${userData.username}\n
- Mot de passe: ${userData.password}\n\n
Pour des raisons de sécurité, veuillez changer votre mot de passe après votre première connexion en utilisant l'option "Réinitialiser le mot de passe" dans l'application.\n\n
Cordialement,\nL'équipe PFE`,
    html: `
      <p>Bonjour ${userData.firstName},</p>
      <p>Votre compte a été créé avec succès. Voici vos informations de connexion :</p>
      <ul>
        <li><strong>Prénom:</strong> ${userData.firstName}</li>
        <li><strong>Nom:</strong> ${userData.lastName}</li>
        <li><strong>Nom d'utilisateur:</strong> ${userData.username}</li>
        <li><strong>Mot de passe:</strong> ${userData.password}</li>
      </ul>
      <p><strong>Pour des raisons de sécurité, veuillez changer votre mot de passe après votre première connexion en utilisant l'option "Réinitialiser le mot de passe" dans l'application.</strong></p>
      <p>Cordialement,<br>L'équipe PFE</p>
    `,
  };

  try {
    // Vérifier la connexion au serveur SMTP
    await transporter.verify();
    console.log(`SMTP connection verified for ${process.env.EMAIL_USER}`);

    // Envoyer l'email
    await transporter.sendMail(mailOptions);
    console.log(`Email sent successfully to ${recipientEmail}`);
  } catch (error: any) {
    console.error(`Failed to send email to ${recipientEmail}:`, error);
    if (error.message.includes("550 5.1.1")) {
      throw new Error("L'adresse email fournie n'existe pas. Veuillez vérifier l'email.");
    }
    throw new Error(`Failed to send email: ${error.message}`);
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
    isActive: true,
    loginAttempts: 0,
    refreshToken: null
  });

  await newUser.save();
  return newUser;
}
  static async getUserById(userId: string): Promise<IUser> {
    this.validateUserId(userId);   
    return await User.findById(new Types.ObjectId(userId))
      .select("-password -refreshToken -loginAttempts -lockUntil")
      .orFail(new Error(ErrorMessages.USER_NOT_FOUND))
      .then(user => user.toObject());
  }
  static async updateUser(userId: string, updateData: Partial<IUser>): Promise<IUser> {
    this.validateUserId(userId);
    this.validateUpdateData(updateData);
    if (updateData.phoneNumber || updateData.username || updateData.email) {
      await this.checkUniqueFields(userId, updateData);
    }   
    if (updateData.password) {
      updateData.password = await this.hashPassword(updateData.password);
    }
    return await User.findByIdAndUpdate(
      new Types.ObjectId(userId),
      updateData,
      { 
        new: true,
        runValidators: true,
        select: "-password -refreshToken -loginAttempts -lockUntil"
      }
    ).orFail(new Error(ErrorMessages.USER_NOT_FOUND))
    .then(user => user.toObject());
  }
  static async deleteUser(userId: string): Promise<IUser> {
    const deletedUser = await User.findByIdAndDelete(userId);
    if (!deletedUser) {
      throw new Error("Utilisateur non trouvé"); // Géré par le catch du contrôleur
    }
    return deletedUser;
  }
  static async getVeterinaireById(userId: string): Promise<IUser> {
    this.validateUserId(userId);
    
    return await User.findOne({
      _id: new Types.ObjectId(userId),
      role: UserRole.VETERINAIRE
    })
    .select("-password -refreshToken -loginAttempts -lockUntil")
    .orFail(new Error("Veterinarian not found"))
    .then(user => user.toObject());
  }
  //#endregion
  //#region Validation Helpers
  private static validateUserData(userData: UserCreateData, extraDetails: ExtraDetails): void {
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
      throw new Error(ErrorMessages.USER_EXISTS);
    }
  }



  private static validateUpdateData(updateData: Partial<IUser>): void {
    if ('role' in updateData) {
      throw new Error(ErrorMessages.ROLE_MODIFICATION);
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
        throw new Error(ErrorMessages.DUPLICATE_FIELDS);
      }
    }
  }

  private static async hashPassword(password: string): Promise<string> {
    this.validatePassword(password);
    return bcrypt.hash(password, 12);
  }

  private static validatePassword(password: string): void {
    if (password.length < PASSWORD_MIN_LENGTH) {
      throw new Error(ErrorMessages.INVALID_PASSWORD);
    }
    if (!/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/[0-9]/.test(password)) {
      throw new Error(ErrorMessages.INVALID_PASSWORD);
    }
  }

  private static validateEmail(email: string): void {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new Error(ErrorMessages.INVALID_EMAIL);
    }
  }

  private static validatePhoneNumber(phone: string): void {
    const phoneRegex = /^[0-9]{8,15}$/;
    if (!phoneRegex.test(phone)) {
      throw new Error(ErrorMessages.INVALID_PHONE);
    }
  }

  private static validateUserDetails(details?: UserDetails): void {
    if (!details) return;

    if (details.services && !this.isStringArray(details.services)) {
      throw new Error("Services must be an array of strings");
    }

    if (details.workingHours) {
      this.validateWorkingHours(details.workingHours);
    }

    if (details.experienceYears !== undefined && 
        (details.experienceYears < 0 || details.experienceYears > 100)) {
      throw new Error("Experience years must be between 0 and 100");
    }
  }

  private static validateWorkingHours(workingHours: WorkingHours[]): void {
    if (!Array.isArray(workingHours)) {
      throw new Error("Invalid working hours format");
    }

    for (const slot of workingHours) {
      if (!slot.day || !slot.start || !slot.end) {
        throw new Error("Each time slot must have day, start and end");
      }

      if (!VALID_DAYS.includes(slot.day as typeof VALID_DAYS[number])) {
        throw new Error(`Invalid day: ${slot.day}`);
      }

      if (!TIME_REGEX.test(slot.start) || !TIME_REGEX.test(slot.end)) {
        throw new Error("Invalid time format (HH:MM required)");
      }

      if (slot.pauseStart && !TIME_REGEX.test(slot.pauseStart)) {
        throw new Error("Invalid pause start time format");
      }

      if (slot.pauseEnd && !TIME_REGEX.test(slot.pauseEnd)) {
        throw new Error("Invalid pause end time format");
      }
    }
  }

  private static validateAddress(address?: Address): void {
    if (!address) return;
    
    Object.entries(address).forEach(([field, value]) => {
      if (value !== undefined && typeof value !== 'string') {
        throw new Error(`Invalid address field: ${field}`);
      }
    });
  }

  private static isStringArray(arr: any[]): boolean {
    return Array.isArray(arr) && arr.every(item => typeof item === 'string');
  }

  private static validateUserId(userId: string): void {
    if (!Types.ObjectId.isValid(userId)) {
      throw new Error(ErrorMessages.INVALID_USER_ID);
    }
  }
  //#endregion
}