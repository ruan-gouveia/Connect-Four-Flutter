import 'package:flutter/material.dart';
import 'package:connect_four_flutter/core/theme/nb_theme.dart';
import 'package:connect_four_flutter/ui/pages/game_page.dart';

class ConnectFourApp extends StatelessWidget {
  const ConnectFourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lig 4',
      debugShowCheckedModeBanner: false,
      theme: NbTheme.light,
      home: const GamePage(),
    );
  }
}
