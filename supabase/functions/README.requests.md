## Folder structure

supabase/
  functions/
    .env.example
    _shared/
      supabase_admin.ts
    wallet-google/
      index.ts
    wallet-apple/
      index.ts
      pass/
        pass.json

## Example request URLs

- Google Wallet:
  `https://<PROJECT_REF>.functions.supabase.co/wallet-google?user_id=<USER_ID>`

- Apple Wallet:
  `https://<PROJECT_REF>.functions.supabase.co/wallet-apple?user_id=<USER_ID>`

## Example frontend calls (JS)

```js
export async function addToGoogleWallet({ baseUrl, userId }) {
  const res = await fetch(`${baseUrl}/wallet-google?user_id=${encodeURIComponent(userId)}`);
  if (!res.ok) throw new Error(await res.text());
  const { url } = await res.json();
  window.location.href = url;
}

export async function downloadApplePass({ baseUrl, userId }) {
  const res = await fetch(`${baseUrl}/wallet-apple?user_id=${encodeURIComponent(userId)}`);
  if (!res.ok) throw new Error(await res.text());
  const blob = await res.blob();
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${userId}.pkpass`;
  a.click();
  URL.revokeObjectURL(a.href);
}
```

