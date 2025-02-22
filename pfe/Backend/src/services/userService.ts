import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User, { IUser, UserRole } from "../models/User";

export class UserService {
  static async createUser(username: string, password: string, role: UserRole): Promise<IUser> {
    const existingUser = await User.findOne({ username });
    if (existingUser) {
      throw new Error("L'utilisateur existe déjà");
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new User({ username, password: hashedPassword, role });
    await newUser.save();
    return newUser;
  }

  // Cette méthode ne prend plus un 'role' en paramètre
  static async authenticateUser(username: string, password: string): Promise<string> {
    const user = await User.findOne({ username }); // On ne cherche plus par 'role'
    if (!user) throw new Error("Utilisateur non trouvé");

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new Error("Identifiants invalides");

    return jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET || "secret", { expiresIn: "1h" });
  }
}
