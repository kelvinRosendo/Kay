import 'package:flutter/material.dart';

import 'screens/main_screen.dart';
import 'theme/kay_theme.dart';

void main() => runApp(const KayApp());

class KayApp extends StatelessWidget {
  const KayApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kay',
    debugShowCheckedModeBanner: false,
    theme: buildKayTheme(),
    home: const MainScreen(),
  );
}