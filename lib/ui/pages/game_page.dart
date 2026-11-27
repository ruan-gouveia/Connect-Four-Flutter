import 'dart:async';

import 'package:flutter/material.dart';

import 'package:connect_four_flutter/controllers/game_controller.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, this.controller});

  final GameController? controller;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? GameController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'Lig 4',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
