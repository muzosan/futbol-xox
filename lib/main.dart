import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoleaApp());
}

class VoleaApp extends StatelessWidget {
  const VoleaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volea',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
