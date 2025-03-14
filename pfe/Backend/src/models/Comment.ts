import mongoose, { Schema, Document } from "mongoose";


export interface IComment extends Document {
  content: string; 
  createdBy: mongoose.Types.ObjectId;
  createdAt: Date; 
}


const CommentSchema: Schema = new Schema({
  content: { type: String, required: true }, // Contenu du commentaire
  createdBy: { type: Schema.Types.ObjectId, refPath: "createdByModel", required: true }, // Référence vers l'utilisateur
  createdAt: { type: Date, default: Date.now }, // Date de création du commentaire
});

export default mongoose.model<IComment>("Comment", CommentSchema);