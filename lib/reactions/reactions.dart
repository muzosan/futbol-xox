import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/engine/common.dart';
import '../theme.dart';

/// Maçta gönderilebilecek hazır emojiler. Serbest yazı bilerek yok:
/// online maçlarda hakaret ve taciz riskini ortadan kaldırır.
const List<String> kReactionEmojis = ['👏', '😂', '😮', '🤔', '😎', '🔥', '😤', '😭'];

/// Emoji baloncuklarının durumu. Online modda aynı sınıf, rakibin emojilerini
/// sunucudan alacak ([receive]) ve kendi emojilerini sunucuya gönderecek ([onSent]).
class ReactionController extends ChangeNotifier {
  ReactionController({
    this.localMark = Mark.x,
    this.cooldown = const Duration(seconds: 3),
    this.visibleFor = const Duration(milliseconds: 2500),
  });

  final Mark localMark;
  final Duration cooldown;
  final Duration visibleFor;

  /// Oyuncu kutularının üstünde gösterilen emojiler
  final Map<Mark, String?> bubbles = {Mark.x: null, Mark.o: null};
  bool opponentMuted = false;

  /// Yerel oyuncu emoji gönderince çağrılır (bot veya sunucu dinler)
  void Function(String emoji)? onSent;

  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<Mark, Timer> _timers = {};
  bool _disposed = false;

  bool get canSend => DateTime.now().difference(_lastSent) >= cooldown;

  /// Yerel oyuncunun emojisi. Bekleme süresi dolmadıysa false döner.
  bool send(String emoji) {
    if (!canSend) return false;
    _lastSent = DateTime.now();
    _show(localMark, emoji);
    onSent?.call(emoji);
    return true;
  }

  /// Rakibin emojisi (bot veya online rakip)
  void receive(String emoji) {
    if (opponentMuted) return;
    _show(localMark.other, emoji);
  }

  void toggleMute() {
    opponentMuted = !opponentMuted;
    if (opponentMuted) bubbles[localMark.other] = null;
    _notify();
  }

  void _show(Mark mark, String emoji) {
    if (_disposed) return;
    _timers[mark]?.cancel();
    bubbles[mark] = emoji;
    _notify();
    _timers[mark] = Timer(visibleFor, () {
      bubbles[mark] = null;
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

/// Botun emoji tepkileri: bazen gol atınca, bazen senin güzel cevabına,
/// bazen de senin emojine karşılık. Hep aynı şeyi yapmasın diye olasılıklı.
class BotReactor {
  BotReactor(this.reactions, {Random? random}) : _random = random ?? Random() {
    reactions.onSent = _onPlayerEmoji;
  }

  final ReactionController reactions;
  final Random _random;
  Timer? _timer;

  static const _replies = {
    '👏': ['👏', '😎'],
    '😂': ['😂', '😤'],
    '😮': ['😎'],
    '🤔': ['😎', '🤔'],
    '😎': ['😤', '🤔'],
    '🔥': ['🔥', '😮'],
    '😤': ['😂', '😎'],
    '😭': ['😂', '👏'],
  };

  void _onPlayerEmoji(String emoji) =>
      _maybe(0.5, _replies[emoji] ?? const ['👏']);

  void onBotScored() => _maybe(0.3, const ['😎', '🔥']);
  void onPlayerScored() => _maybe(0.25, const ['😮', '👏']);
  void onPlayerMissed() => _maybe(0.15, const ['🤔', '😂']);
  void onGameEnd({required bool botWon}) =>
      _maybe(0.8, botWon ? const ['😎', '🔥'] : const ['👏', '😭']);

  void _maybe(double chance, List<String> options) {
    if (_random.nextDouble() >= chance) return;
    final emoji = options[_random.nextInt(options.length)];
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: 700 + _random.nextInt(1300)),
        () => reactions.receive(emoji));
  }

  void dispose() => _timer?.cancel();
}

/// Üst çubuktaki emoji butonu: emoji seçimi + rakibi sessize alma.
class ReactionButton extends StatelessWidget {
  const ReactionButton({super.key, required this.controller});

  final ReactionController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Emoji gönder',
      icon: const Icon(Icons.emoji_emotions_outlined),
      onPressed: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: controller,
        builder: (ctx, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in kReactionEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final sent = controller.send(e);
                        Navigator.pop(ctx);
                        if (!sent) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Biraz bekle, çok hızlı gönderiyorsun.'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: controller.opponentMuted,
                onChanged: (_) => controller.toggleMute(),
                title: const Text('Rakibin emojilerini gizle'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oyuncu kutusunun üstünde beliren emoji baloncuğu.
class ReactionBubble extends StatelessWidget {
  const ReactionBubble({super.key, required this.emoji});

  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: child,
      ),
      child: emoji == null
          ? const SizedBox.shrink(key: ValueKey('bos'))
          : Container(
              key: ValueKey(emoji),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 8),
                ],
              ),
              child: Text(emoji!, style: const TextStyle(fontSize: 24)),
            ),
    );
  }
}
