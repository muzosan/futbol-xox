import 'dart:async';

import 'package:flutter/foundation.dart';

/// Hamle süresini sayan ortak parça. Süre dolunca [onTurnExpired] çağrılır.
/// Online modda süreyi sunucu tutacağı için bu sadece yerel oyunlarda kullanılır.
mixin TurnTimer on ChangeNotifier {
  int get turnSeconds;

  int secondsLeft = 0;
  Timer? _turnTimer;

  void startTurnTimer() {
    _turnTimer?.cancel();
    secondsLeft = turnSeconds;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        _turnTimer?.cancel();
        onTurnExpired();
      } else {
        notifyListeners();
      }
    });
  }

  void stopTurnTimer() => _turnTimer?.cancel();

  void onTurnExpired();
}
