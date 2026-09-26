import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../game/ai_player.dart';
import '../theme.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Repository> _repoFuture = Repository.load();
  bool _vsBot = true;

  static const _levels = [
    _Level('kolay', 'Kolay', 'Bol cevaplı tablolar', 'Acemi bot',
        AppColors.primary, Icons.sentiment_satisfied_alt, BotLevel.easy),
    _Level('orta', 'Orta', 'Dengeli tablolar', 'Tecrübeli bot',
        AppColors.amber, Icons.local_fire_department_outlined,
        BotLevel.medium),
    _Level('zor', 'Zor', 'Az bilinen eşleşmeler', 'Uzman bot', AppColors.o,
        Icons.psychology_outlined, BotLevel.hard),
  ];

  void _start(Repository repo, _Level level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          repo: repo,
          difficulty: level.key,
          botLevel: _vsBot ? level.bot : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.9),
            radius: 1.3,
            colors: [
              AppColors.primary.withValues(alpha: 0.13),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<Repository>(
            future: _repoFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Veri yüklenemedi:\n${snapshot.error}',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildMenu(snapshot.data!);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(Repository repo) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sports_soccer,
                      size: 52, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'FUTBOL XOX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Satırdaki ve sütundaki iki kulüpte de oynamış bir futbolcu '
                'bul. Üç hücreyi yan yana, alt alta ya da çapraz dizen kazanır!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 32),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Bota Karşı'),
                    icon: Icon(Icons.smart_toy_outlined),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('2 Kişilik'),
                    icon: Icon(Icons.people_outline),
                  ),
                ],
                selected: {_vsBot},
                onSelectionChanged: (s) => setState(() => _vsBot = s.first),
              ),
              const SizedBox(height: 20),
              for (final level in _levels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LevelTile(
                    level: level,
                    subtitle: _vsBot
                        ? '${level.gridText} · ${level.botText}'
                        : level.gridText,
                    onTap: () => _start(repo, level),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '${repo.players.length} oyuncu · ${repo.grids.length} tablo',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Level {
  const _Level(this.key, this.title, this.gridText, this.botText, this.color,
      this.icon, this.bot);

  final String key;
  final String title;
  final String gridText;
  final String botText;
  final Color color;
  final IconData icon;
  final BotLevel bot;
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.subtitle,
    required this.onTap,
  });

  final _Level level;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: level.color.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: level.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(level.icon, color: level.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: level.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
