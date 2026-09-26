import 'package:flutter/material.dart';

import '../data/records.dart';
import '../data/repository.dart';
import '../game/ai_player.dart';
import '../theme.dart';
import 'chain_screen.dart';
import 'game_screen.dart';
import 'hunt_screen.dart';
import 'quiz_screen.dart';
import 'who_screen.dart';

enum GameMode { xox, hunt, chain, quiz, who }

class _ModeInfo {
  const _ModeInfo(this.title, this.icon, this.description, this.levelTexts,
      {this.solo = false});

  final String title;
  final IconData icon;
  final String description;

  /// Kolay / orta / zor alt yazıları
  final List<String> levelTexts;

  /// Tek kişilik mod (bot veya 2 kişilik seçimi yok)
  final bool solo;
}

const Map<GameMode, _ModeInfo> _modes = {
  GameMode.xox: _ModeInfo(
    'XOX',
    Icons.grid_3x3,
    'Satırdaki ve sütundaki iki kulüpte de oynamış bir futbolcu bul. Üç '
        'hücreyi yan yana, alt alta ya da çapraz dizen kazanır!',
    ['Bol cevaplı tablolar', 'Dengeli tablolar', 'Az bilinen eşleşmeler'],
  ),
  GameMode.hunt: _ModeInfo(
    'Kulüp Avı',
    Icons.hub_outlined,
    'Ekrana gelen 5 kulübün en çoğunda oynamış futbolcuyu bul. Ne kadar çok '
        'kulüp, o kadar çok puan! 3 turun sonunda en çok puanı toplayan kazanır.',
    ['Bol ortaklı kulüpler', 'Dengeli kulüpler', 'Az bağlantılı kulüpler'],
  ),
  GameMode.chain: _ModeInfo(
    'Zincir',
    Icons.link,
    'Son futbolcuyla aynı kulüpte oynamış başka bir futbolcu yaz, zinciri '
        'uzat. Yanlış cevap bir can götürür; canı biten kaybeder!',
    ['Çok ünlü başlangıç', 'Tanınmış başlangıç', 'Az bilinen başlangıç'],
  ),
  GameMode.quiz: _ModeInfo(
    'Doğru mu?',
    Icons.bolt,
    '60 saniyede olabildiğince çok soruyu bil: "Bu futbolcu bu kulüpte oynadı '
        'mı?" Yanlış cevap süreden 5 saniye götürür.',
    ['Ünlü oyuncular', 'Tanınmış oyuncular', 'Az bilinen oyuncular'],
    solo: true,
  ),
  GameMode.who: _ModeInfo(
    'Kim Bu?',
    Icons.person_search,
    'Bir futbolcunun kariyerindeki kulüpler sırayla açılır. Ne kadar az '
        'ipucuyla bilirsen o kadar çok puan! 5 soru, soru başına 10 puan.',
    ['Çok ünlü oyuncular', 'Tanınmış oyuncular', 'Az bilinen oyuncular'],
    solo: true,
  ),
};

/// Tek kişilik modların rekor anahtarları
String? _recordKey(GameMode mode, String difficulty) => switch (mode) {
      GameMode.quiz => QuizScreen.recordKey(difficulty),
      GameMode.who => WhoScreen.recordKey(difficulty),
      _ => null,
    };

class _Level {
  const _Level(this.key, this.title, this.botText, this.color, this.icon,
      this.bot);

  final String key;
  final String title;
  final String botText;
  final Color color;
  final IconData icon;
  final BotLevel bot;
}

const List<_Level> _levels = [
  _Level('kolay', 'Kolay', 'Acemi bot', AppColors.primary,
      Icons.sentiment_satisfied_alt, BotLevel.easy),
  _Level('orta', 'Orta', 'Tecrübeli bot', AppColors.amber,
      Icons.local_fire_department_outlined, BotLevel.medium),
  _Level('zor', 'Zor', 'Uzman bot', AppColors.o, Icons.psychology_outlined,
      BotLevel.hard),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Repository> _repoFuture = Repository.load();
  bool _vsBot = true;
  GameMode _mode = GameMode.xox;
  Map<String, int> _records = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = <String, int>{};
    for (final mode in GameMode.values) {
      for (final level in _levels) {
        final key = _recordKey(mode, level.key);
        if (key != null) records[key] = await Records.best(key);
      }
    }
    if (mounted) setState(() => _records = records);
  }

  Future<void> _start(Repository repo, _Level level) async {
    final bot = _vsBot ? level.bot : null;
    final Widget screen = switch (_mode) {
      GameMode.xox =>
        GameScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.hunt =>
        HuntScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.chain =>
        ChainScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.quiz => QuizScreen(repo: repo, difficulty: level.key),
      GameMode.who => WhoScreen(repo: repo, difficulty: level.key),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadRecords(); // yeni rekor olmuş olabilir
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
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Oyuncular yükleniyor…',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                );
              }
              return _buildMenu(snapshot.data!);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(Repository repo) {
    final info = _modes[_mode]!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
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
                      size: 44, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'FUTBOL XOX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 24),
              // Mod seçimi
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: [
                  for (final mode in GameMode.values)
                    _ModeCard(
                      info: _modes[mode]!,
                      selected: _mode == mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 64,
                child: Text(
                  info.description,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              if (!info.solo) ...[
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
              ] else ...[
                const Text(
                  'Tek kişilik · Rekorunu geliştir',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 20),
              ],
              for (var i = 0; i < _levels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LevelTile(
                    level: _levels[i],
                    subtitle: [
                      info.levelTexts[i],
                      if (info.solo)
                        'Rekor: ${_records[_recordKey(_mode, _levels[i].key)] ?? 0}'
                      else if (_vsBot)
                        _levels[i].botText,
                    ].join(' · '),
                    onTap: () => _start(repo, _levels[i]),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '${repo.players.length} oyuncu · ${repo.clubs.length} kulüp',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _ModeInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(info.icon, color: color, size: 26),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    info.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
