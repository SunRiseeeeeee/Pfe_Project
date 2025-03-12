import swaggerJsdoc from "swagger-jsdoc";
import swaggerUi from "swagger-ui-express";
import { Express } from "express";

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Veterinary API",
      version: "1.0.0",
      description: "API documentation for the veterinary system",
    },
    servers: [
      {
        url: "http://localhost:3000/api",
        description: "Development Server",
      },
    ],
  },
  apis: ["./src/routes/*.ts"], // Assurez-vous que vos routes sont bien prises en compte
};

const swaggerSpec = swaggerJsdoc(options);

export const setupSwagger = (app: Express) => {
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  console.log("✅ Swagger docs available at http://localhost:3000/api-docs");
};
