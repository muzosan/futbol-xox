import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await L10n.instance.load(); // kayıtlı dil ya da telefonun dili
  runApp(const VoleaApp());
}

class VoleaApp extends StatelessWidget {
  const VoleaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dil değişince uygulama baştan çizilir (veri önbellekte, tekrar yüklenmez).
    // Arapça seçilince Flutter arayüzü otomatik olarak sağdan sola çevirir.
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => MaterialApp(
        key: ValueKey(currentLang),
        title: 'Volea',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: L10n.instance.locale,
        supportedLocales: [for (final l in kLangs) Locale(l.code)],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
