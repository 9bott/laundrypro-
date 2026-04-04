# Point — دليل الإعداد الكامل

## المتطلبات / Requirements

- Flutter SDK 3.19+ : https://flutter.dev/docs/get-started/install
- Dart 3.3+
- Supabase account (free): https://supabase.com
- Firebase account (free): https://firebase.google.com
- Unifonic account (paid, Saudi Arabia SMS): https://unifonic.com
- Android Studio OR VS Code with Flutter extension

**If `android/` or `ios/` are missing**, from the project root run:

`flutter create . --org com.laundrypro --project-name laundrypro --platforms android,ios`

Then re-run `flutter pub get` and apply any platform overrides described in this repo (e.g. `android/app/build.gradle`).

## الخطوة 1 — Supabase

1. أنشئ مشروع جديد على https://app.supabase.com
2. احفظ: Project URL و anon public key
3. افتح SQL Editor وشغّل بالترتيب:

   - supabase/migrations/001_initial_schema.sql
   - supabase/migrations/002_rls_policies.sql
   - supabase/migrations/003_seed_data.sql
   - supabase/migrations/004_indexes.sql

4. في Supabase Dashboard → Authentication → Providers:

   - فعّل Phone provider
   - أضف Twilio أو Vonage للـ OTP (أو استخدم Supabase built-in test OTPs للتطوير)

## الخطوة 2 — Edge Functions

```text
cd supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set UNIFONIC_API_KEY=your_key
supabase secrets set FCM_SERVER_KEY=your_key
supabase functions deploy --no-verify-jwt scheduled-notifications
supabase functions deploy add-purchase
supabase functions deploy redeem-balance
supabase functions deploy add-subscription
supabase functions deploy get-customer-by-qr
supabase functions deploy generate-qr-token
supabase functions deploy get-owner-dashboard
supabase functions deploy send-notification
```

## الخطوة 3 — Flutter App

```text
flutter pub get
flutter gen-l10n
```

**للتشغيل:**

```text
flutter run --dart-define=SUPABASE_URL=your_url \
            --dart-define=SUPABASE_ANON_KEY=your_key
```

## الخطوة 4 — البناء للمتاجر

### Android (Google Play):

**أولاً أنشئ keystore:**

```text
keytool -genkey -v -keystore laundrypro.keystore \
  -alias laundrypro -keyalg RSA -keysize 2048 -validity 10000
```

**ضع القيم في android/key.properties**

**ابنِ الـ AAB:**

```text
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key
```

**الملف هنا:** build/app/outputs/bundle/release/app-release.aab

### iOS (App Store):

```text
open ios/Runner.xcworkspace
```

**في Xcode:**

1. Signing & Capabilities → فعّل Push Notifications
2. General → Bundle Identifier: com.laundrypro.app
3. Product → Archive
4. Distribute App → App Store Connect

## بيانات الاختبار الافتراضية

بعد تشغيل seed_data.sql، يمكنك:

- تسجيل دخول بأي رقم هاتف سعودي (الـ OTP سيكون 123456 في وضع dev)
- إنشاء موظف تجريبي من لوحة تحكم المالك
- تجربة كل الوظائف على بيانات وهمية
