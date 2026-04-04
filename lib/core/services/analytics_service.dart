/// Analytics abstraction — wire Firebase Analytics or similar later.
class AnalyticsService {
  AnalyticsService._();

  static void logEvent(String name, [Map<String, Object?>? params]) {
    // TODO: FirebaseAnalytics.instance.logEvent(...)
  }
}
