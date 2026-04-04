import { JWT } from "google-auth-library";
import { readFile } from "node:fs/promises";
import jwt from "jsonwebtoken";

async function main() {
  const svc = JSON.parse(
    await readFile(new URL("./service-account.json", import.meta.url))
  );

  const email = svc.client_email;
  const privateKey = (svc.private_key ?? "").replace(/\\n/g, "\n");

  if (!email || !privateKey) throw new Error("Invalid service-account.json");

  const classId = "3388000000023107513.laundry-loyalty-3";
  const issuerId = classId.split(".")[0];

  const userId = "user-123";
  const objectId = `${issuerId}.${userId}`;

  // access token
  const client = new JWT({
    email,
    key: privateKey,
    scopes: ["https://www.googleapis.com/auth/wallet_object.issuer"],
  });

  const { token } = await client.getAccessToken();
  if (!token) throw new Error("Failed to get access token");

  // إنشاء object (وتجاهل 409)
  const objectBody = {
    id: objectId,
    classId,
    state: "ACTIVE",
    accountName: "Osama",
    barcode: {
      type: "QR_CODE",
      value: userId,
    },
  };

  const res = await fetch(
    "https://walletobjects.googleapis.com/walletobjects/v1/loyaltyObject",
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(objectBody),
    }
  );

  const text = await res.text();

  if (!res.ok && res.status !== 409) {
    console.error(`Error (${res.status}): ${text}`);
    process.exit(1);
  }

  console.log("Object ready");

  // JWT (مهم: يحتوي بيانات كاملة عشان demo mode)
  const claims = {
    iss: email,
    aud: "google",
    typ: "savetowallet",
    payload: {
      loyaltyObjects: [
        {
          id: objectId,
          classId: classId,
          state: "ACTIVE",
          accountName: "Osama",
          barcode: {
            type: "QR_CODE",
            value: userId,
          },
        },
      ],
    },
  };

  const tokenJwt = jwt.sign(claims, privateKey, {
    algorithm: "RS256",
  });

  console.log("Wallet URL:");
  console.log(`https://pay.google.com/gp/v/save/${tokenJwt}`);
}

main().catch((err) => {
  console.error("Error:", err?.message ?? err);
  process.exitCode = 1;
});