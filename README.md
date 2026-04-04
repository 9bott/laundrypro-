# Point — Loyalty & Wallet System

A complete Flutter + Supabase mobile app for laundry shop loyalty management.

## Features

- Customer QR wallet with auto-rotating codes (60-second refresh)
- 20% automatic cashback on every purchase
- Prepaid subscription plans (pay 100, get 120 SAR)
- Staff counter app optimized for 8-second transactions
- Owner dashboard with fraud detection
- Offline transaction queue with auto-sync
- Arabic-first RTL UI
- SMS notifications via Unifonic

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) + Riverpod + GoRouter |
| Backend | Supabase (PostgreSQL + Edge Functions) |
| Auth | Supabase Phone OTP |
| Notifications | Firebase FCM + Unifonic SMS |
| QR | qr_flutter + mobile_scanner |

## User Roles

- **Customer** — QR code, wallet balance, transaction history
- **Staff** — QR scanner, fast transaction entry, undo support
- **Owner** — Dashboard, reports, fraud alerts, staff management

## Project Structure

See `/lib` folder — organized by feature (auth/customer/staff/owner).

## Setup

See SETUP.md for complete setup instructions.

## Security

- All financial logic runs in Supabase Edge Functions (server-side only)
- Dynamic QR codes expire every 60 seconds (prevents screenshot fraud)
- Row Level Security on all Supabase tables
- Append-only audit log
- Automatic fraud detection flags
