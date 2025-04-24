export enum UserRole {
    CLIENT = 'client',
    VETERINAIRE = 'veterinaire',
    SECRETAIRE = 'secretaire',
    ADMIN = 'admin',
}

export interface User {
    id: string;
    firstName: string;
    lastName: string;
    email: string;
    username: string;
    role: UserRole;
}

export interface AuthTokens {
    accessToken: string;
    refreshToken: string;
}

export interface AuthResponse {
    success: boolean;
    message: string;
    tokens?: AuthTokens;
    user?: User;
    userId?: string;
    error?: string; // Ajouté pour gérer les erreurs
    errorType?: string; // Ajouté pour typer les erreurs
}