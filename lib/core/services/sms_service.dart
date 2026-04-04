/// Unifonic (or server-mediated) SMS — **never** ship API secrets in the app.
/// Production: call Supabase Edge Function that uses Unifonic REST API.
class SmsService {
  SmsService._();

  /// Triggers server-side OTP SMS; [phoneE164] e.g. +9665xxxxxxxx
  Future<void> requestOtpViaBackend(String phoneE164) async {
    // TODO: supabase.functions.invoke('send_otp_sms', body: {...})
  }
}
