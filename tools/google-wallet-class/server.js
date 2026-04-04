const express = require("express");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const crypto = require("crypto");

// ===== load service account =====
const SERVICE_ACCOUNT_PATH = path.join(__dirname, "service-account.json");
const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, "utf8"));

const SERVICE_ACCOUNT_EMAIL = serviceAccount.client_email;
const PRIVATE_KEY = String(serviceAccount.private_key || "").replace(/\\n/g, "\n");

const CLASS_ID = "3388000000023107513.laundry-loyalty-3";
const ISSUER_ID = CLASS_ID.split(".")[0];

const app = express();
app.use(express.json());

// ===== base64url =====
function base64url(input) {
  return Buffer.from(JSON.stringify(input))
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

// ===== sign manually =====
function signJwt(header, payload, privateKey) {
  const encodedHeader = base64url(header);
  const encodedPayload = base64url(payload);
  const data = `${encodedHeader}.${encodedPayload}`;

  const signature = crypto
    .createSign("RSA-SHA256")
    .update(data)
    .end()
    .sign(privateKey);

  const encodedSignature = signature
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${data}.${encodedSignature}`;
}

// ===== API =====
app.post("/wallet/pass", (req, res) => {
  const { userId, name } = req.body;

  const objectId = `${ISSUER_ID}.${userId}`;

  const header = {
    alg: "RS256",
    typ: "savetowallet",
  };

  const payload = {
    iss: SERVICE_ACCOUNT_EMAIL,
    aud: "google",
    typ: "savetowallet",

    payload: {
      loyaltyObjects: [
        {
          id: objectId,
          classId: CLASS_ID,
          state: "ACTIVE",
          accountName: name,
          barcode: {
            type: "QR_CODE",
            value: userId,
          },
        },
      ],
    },
  };

  const token = signJwt(header, payload, PRIVATE_KEY);

  res.json({
    url: `https://pay.google.com/gp/v/save/${token}`,
  });
});

app.listen(3000, () => {
  console.log("Server running on 3000");
});