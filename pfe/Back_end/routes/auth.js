const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");

const router = express.Router();

// Fonction pour inscription
const registerUser = async (req, res, role) => {
  try {
    const { name, email, password, phoneNumber } = req.body;

    let user = await User.findOne({ email });
    if (user) return res.status(400).json({ msg: "L'utilisateur existe déjà" });

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    user = new User({ name, email, password: hashedPassword, phoneNumber, role });
    await user.save();

    res.status(201).json({ msg: `${role} enregistré avec succès` });
  } catch (err) {
    res.status(500).json({ msg: "Erreur serveur" });
  }
};

// Fonction pour connexion
const loginUser = async (req, res, role) => {
  try {
    const { email, password } = req.body;

    let user = await User.findOne({ email, role });
    if (!user) return res.status(400).json({ msg: `${role} non trouvé` });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ msg: "Mot de passe incorrect" });

    const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: "1h" });

    res.json({ token, user: { id: user._id, name: user.name, email: user.email, role: user.role } });
  } catch (err) {
    res.status(500).json({ msg: "Erreur serveur" });
  }
};

// Routes d'inscription
router.post("/user/signup", (req, res) => registerUser(req, res, "user"));
router.post("/secretary/signup", (req, res) => registerUser(req, res, "secretary"));
router.post("/veterinarian/signup", (req, res) => registerUser(req, res, "veterinarian"));

// Routes de connexion
router.post("/user/login", (req, res) => loginUser(req, res, "user"));
router.post("/secretary/login", (req, res) => loginUser(req, res, "secretary"));
router.post("/veterinarian/login", (req, res) => loginUser(req, res, "veterinarian"));

module.exports = router;
