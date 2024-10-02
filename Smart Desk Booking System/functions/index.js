"use strict";
import express from "express";
import bodyParser from "body-parser";
import admin from "firebase-admin";
import functions from "firebase-functions";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const serviceAccount = JSON.parse(readFileSync(join(__dirname, "./serviceAccountKey.json"), "utf-8"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://fire-setup-b5eb2-default-rtdb.firebaseio.com/",
});

const app = express();
app.use(bodyParser.json());

app.post("/authenticate", async (req, res) => {
    // get employeeId and token from requestment
  const employeeId = req.body.employeeId || req.query.employeeId;
  const token = req.body.token || req.query.token;
  
   if (!employeeId || !token) {
    return res.status(400).json({ error: "employeeId and token are required" });
  }

   // if not get employeeId and token then return error
try {
    const customToken = await admin.auth().createCustomToken(employeeId);
    res.json({ customToken });
  } catch (error) {
    console.error("Error creating custom token:", error);
    res.status(500).json({ error: "Failed to create custom token" });
  }
});

// Export the Express app as a Firebase function
export const api = functions.https.onRequest(app);



