import { JWT } from "google-auth-library";
import { readFile } from "node:fs/promises";

async function main() {
  const svc = JSON.parse(
    await readFile(new URL("./service-account.json", import.meta.url))
  );

  const email = svc.client_email;
  const privateKey = (svc.private_key ?? "").replace(/\\n/g, "\n");

  if (!email || !privateKey) throw new Error("Invalid service-account.json");

  const issuerId = "3388000000023107513";

  // غيرنا ID عشان نتفادى القديم
  const classId = `${issuerId}.laundry-loyalty-3`;

  const client = new JWT({
    email,
    key: privateKey,
    scopes: ["https://www.googleapis.com/auth/wallet_object.issuer"],
  });

  const { token } = await client.getAccessToken();
  if (!token) throw new Error("Failed to get access token");

  const body = {
    id: classId,
    issuerName: "Laundry App",
    programName: "Laundry Loyalty",
    reviewStatus: "UNDER_REVIEW",

    // ✅ صورة PNG Public شغالة
    programLogo: {
      sourceUri: {
        uri: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/React-icon.svg/512px-React-icon.svg.png",
      },
    },
  };

  const res = await fetch(
    "https://walletobjects.googleapis.com/walletobjects/v1/loyaltyClass",
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  const text = await res.text();

  if (!res.ok) {
    console.error(`Error (${res.status}): ${text}`);
    process.exit(1);
  }

  console.log("Created loyalty class:");
  console.log(JSON.parse(text));
}

main().catch((err) => {
  console.error("Error:", err?.message ?? err);
  process.exitCode = 1;
});