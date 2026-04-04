import 'package:flutter/services.dart';

/// Staff counter UX: haptics + system sounds (no extra assets).
void staffHaptic() {
  HapticFeedback.mediumImpact();
}

void staffSuccessSound() {
  SystemSound.play(SystemSoundType.alert);
}
