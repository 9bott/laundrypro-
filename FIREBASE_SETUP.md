# Firebase Setup Guide for Point

## Step 1 — Create Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Add project" → name it "Point"
3. Disable Google Analytics (not needed)
4. Click "Create project"

## Step 2 — Android App

1. In Firebase console: click Android icon
2. Package name: com.laundrypro.app
3. App nickname: Point Android
4. Download google-services.json
5. Place it at: android/app/google-services.json  
   (This file is in .gitignore — never commit it)  
6. The `com.google.gms.google-services` Gradle plugin is already enabled; builds require this file. For CI without Firebase, temporarily remove that plugin line from `android/app/build.gradle`.

**FCM service:** Do not declare `FirebaseMessagingService` directly in `AndroidManifest.xml` — the class is abstract. Rely on the merged manifests from the `firebase_messaging` Flutter plugin (or your own subclass of `FirebaseMessagingService`).

## Step 3 — iOS App

1. In Firebase console: click iOS icon
2. Bundle ID: com.laundrypro.app
3. App nickname: Point iOS
4. Download GoogleService-Info.plist
5. Open Xcode → drag file into Runner/Runner folder  
   (This file is in .gitignore — never commit it)

## Step 4 — Enable Cloud Messaging

1. Firebase console → Project Settings → Cloud Messaging
2. Note your Server Key (for UNIFONIC or direct FCM calls)
3. For iOS: upload your APNs Authentication Key  
   (Generate from Apple Developer Portal → Keys → +)

## Step 5 — Supabase FCM Integration

In your Supabase Edge Function environment variables, add:

`FCM_SERVER_KEY=your_server_key_from_step_4`
