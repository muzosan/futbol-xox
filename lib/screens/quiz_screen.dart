import 'package:flutter/material.dart';

import '../data/records.dart';
import '../data/repository.dart';
import '../game/quiz_controller.dart';
import '../report/report.dart';
import '../theme.dart';
import '../widgets/board.dart' show ClubHeader;
import 'game_screen.dart' show difficultyLabels;
import '../l10n/l10n.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.repo, required this.difficulty});

  final Repository repo;
  final String difficulty;

  static String recordKey(String difficulty) => 'quiz_$difficulty';

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late QuizController _game;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    super.dispose();
  }

  void _createGame() {
    _game = QuizController(repo: widget.repo, difficulty: widget.difficulty);
    _game.addListener(_onGameChanged);
    _resultShown = false;
  }

  void _restart() {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    setState(_createGame);
  }

  void _onGameChanged() {
    if (_game.isOver && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  Future<void> _showResult() async {
    final key = QuizScreen.recordKey(widget.difficulty);
    final score = _game.engine.score;
    final oldBest = await Records.best(key);
    final isRecord = await Records.submit(key, score);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          isRecord ? Icons.emoji_events : Icons.timer_off_outlined,
          size: 40,
          color: isRecord ? AppColors.amber : AppColors.textMuted,
        ),
        title: Text(isRecord ? t('common.new_record') : t('common.time_up')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoldText('$score', size: 72, spacing: 1),
            Text(t('quiz.correct_answers'),
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            Text(
              '${t('quiz.best_streak', {'n': _game.engine.bestStreak})}\n'
              '${t('common.record', {'n': isRecord ? score : oldBest})}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(t('common.main_menu')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restart();
            },
            child: Text(t('common.play_again')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diffLabel = difficultyLabels[widget.difficulty] ?? widget.difficulty;

    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        final engine = _game.engine;
        final player = _game.questionPlayer;
        final lowTime = engine.timeLeft <= 10;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              t('quiz.title', {'diff': diffLabel}),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Skor, süre, seri
                  Row(
                    children: [
                      _Stat(label: t('quiz.points'), value: '${engine.score}'),
                      const Spacer(),
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: engine.timeLeft / engine.durationSeconds,
                                strokeWidth: 6,
                                backgroundColor: AppColors.surfaceHigh,
                                color: lowTime
                                    ? AppColors.danger
                                    : AppColors.primary,
                              ),
                            ),
                            Text(
                              '${engine.timeLeft}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: lowTime
                                    ? AppColors.danger
                                    : AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _Stat(label: t('quiz.streak'), value: '🔥 ${engine.streak}'),
                    ],
                  ),
                  const Spacer(),
                  // Soru
                  Text(
                    upper(player.name),
                    textAlign: TextAlign.center,
                    style: displayStyle(40),
                  ),
                  if (player.birthYear != null)
                    Text(t('common.born', {'y': player.birthYear}),
                        style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 18),
                  Text(t('quiz.question'),
                      style:
                          TextStyle(fontSize: 16, color: AppColors.textMuted)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 130,
                    child: ClubHeader(club: _game.questionClub),
                  ),
                  const Spacer(),
                  _FeedbackLine(game: _game),
                  const SizedBox(height: 16),
                  // Cevap butonları
                  Row(
                    children: [
                      Expanded(
                        child: _AnswerButton(
                          label: t('quiz.no'),
                          icon: Icons.close,
                          color: AppColors.danger,
                          onTap: _game.isOver ? null : () => _game.answer(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AnswerButton(
                          label: t('quiz.yes'),
                          icon: Icons.check,
                          color: AppColors.success,
                          onTap: _game.isOver ? null : () => _game.answer(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: displayStyle(34)),
        ],
      ),
    );
  }
}

/// Son cevabın sonucu: doğruysa kısa onay, yanlışsa doğrusu.
class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({required this.game});

  final QuizController game;

  @override
  Widget build(BuildContext context) {
    final fb = game.lastFeedback;
    if (fb == null) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(t('quiz.penalty_hint'),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
      );
    }
    final player = game.repo.playerById(fb.question.playerId)!;
    final club = game.repo.club(fb.question.clubId);
    final text = fb.correct
        ? t('quiz.correct')
        : t(fb.question.isTrue ? 'quiz.wrong_did' : 'quiz.wrong_didnt',
            {'name': player.name, 'club': club.name});
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: fb.correct ? AppColors.primary : AppColors.danger,
              ),
            ),
          ),
          if (!fb.correct)
            TextButton(
              onPressed: () => showReportDialog(
                context,
                DataReport(
                  mode: t('mode.quiz.title'),
                  player: player,
                  clubs: [club],
                  claim: fb.question.isTrue
                      ? t('quiz.claim_did')
                      : t('quiz.claim_didnt'),
                ),
              ),
              child: Text(t('quiz.dispute')),
            ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 76,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: radius,
          border: Border.all(color: color, width: 2),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
