import 'package:flutter/material.dart';

import '../data/repository.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Repository> _repoFuture = Repository.load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Repository>(
          future: _repoFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Veri yüklenemedi:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final repo = snapshot.data!;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.sports_soccer,
                          size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Futbol XOX',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Satırdaki ve sütundaki iki kulüpte de oynamış bir '
                        'futbolcu bul. Üç hücreyi yan yana, alt alta ya da '
                        'çapraz dizen kazanır!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        '2 Kişilik · Aynı Telefon',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      for (final entry in difficultyLabels.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GameScreen(
                                  repo: repo,
                                  difficulty: entry.key,
                                ),
                              ),
                            ),
                            child: Text(entry.value,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        '${repo.players.length} oyuncu · '
                        '${repo.grids.length} tablo',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
