const mongoose = require("mongoose");

const UserSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  email: { 
    type: String, 
    required: true, 
    unique: true, 
    trim: true, 
    lowercase: true,
    match: [/^\S+@\S+\.\S+$/, "Invalid email format"] // Vérification de l'email
  },
  password: { type: String, required: true },
  phoneNumber: { 
    type: String, 
    required: true, 
    trim: true,
    match: [/^\d{8,15}$/, "Invalid phone number"] // Vérifie que c'est bien un numéro
  },
  role: { 
    type: String, 
    enum: ["user", "secretary", "veterinarian"], 
    required: true 
  }
});

module.exports = mongoose.model("User", UserSchema);
