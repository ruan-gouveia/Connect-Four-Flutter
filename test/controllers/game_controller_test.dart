import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_four_flutter/controllers/game_controller.dart';
import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/logic/cpu_ai.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/game_state.dart';
import 'package:connect_four_flutter/models/player.dart';
import 'package:connect_four_flutter/services/game_storage_service.dart';

class _ScriptedCpuAi extends CpuAi {
  _ScriptedCpuAi(this.moves);

  final List<int> moves;
  int calls = 0;

  @override
  Future<int> chooseMove(List<Player> board, CpuDifficulty difficulty) async {
    calls++;
    if (moves.isEmpty) return -1;
    final idx = calls - 1 < moves.length ? calls - 1 : moves.length - 1;
    return moves[idx];
  }
}

class _CompleterCpuAi extends CpuAi {
  Completer<int>? pendingCompleter;
  int calls = 0;

  @override
  Future<int> chooseMove(List<Player> board, CpuDifficulty difficulty) {
    calls++;
    final completer = Completer<int>();
    pendingCompleter = completer;
    return completer.future;
  }
}

class _MemoryGameStorage extends GameStorageService {
  GameSnapshot? snapshot;
  final List<GameSnapshot> savedSnapshots = [];

  @override
  Future<void> saveSnapshot(GameSnapshot snapshot) async {
    this.snapshot = snapshot;
    savedSnapshots.add(snapshot);
  }

  @override
  Future<GameSnapshot?> loadSnapshot() async => snapshot;
}

void main() {
  group('GameController', () {
    test('inicia com tabuleiro vazio, placar zerado e dificuldade média', () {
      final controller = GameController(ai: _ScriptedCpuAi([3]));
      addTearDown(controller.dispose);

      expect(controller.board.length, 42);
      expect(controller.board.every((cell) => cell == Player.none), isTrue);
      expect(controller.isGameOver, isFalse);
      expect(controller.isCpuThinking, isFalse);
      expect(controller.winner, Player.none);
      expect(controller.winCells, isEmpty);
      expect(controller.moves, 0);
      expect(controller.lastMoveIndex, -1);
      expect(controller.humanWins, 0);
      expect(controller.cpuWins, 0);
      expect(controller.draws, 0);
      expect(controller.difficulty, CpuDifficulty.medium);
    });

    test('humano joga primeiro (vermelho) e CPU responde após delay (azul)', () async {
      final ai = _ScriptedCpuAi([2]);
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      controller.playHumanColumn(3);

      expect(controller.board[BoardEngine.indexOf(5, 3)], Player.human);
      expect(controller.lastMoveIndex, BoardEngine.indexOf(5, 3));
      expect(controller.moves, 1);
      expect(controller.isCpuThinking, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ai.calls, 1);
      expect(controller.isCpuThinking, isFalse);
      expect(controller.board[BoardEngine.indexOf(5, 2)], Player.cpu);
      expect(controller.lastMoveIndex, BoardEngine.indexOf(5, 2));
      expect(controller.moves, 2);
    });

    test('ignora entradas durante isCpuThinking, em coluna cheia ou inválida sem notificar', () async {
      final ai = _ScriptedCpuAi([0, 0, 0, 1, 1, 1]);
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: const Duration(milliseconds: 25),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      // Colunas fora do intervalo 0..6
      controller.playHumanColumn(-1);
      controller.playHumanColumn(7);
      expect(notifications, 0);

      // Jogada válida dispara 1 notificação e bloqueia novo clique enquanto pensa
      controller.playHumanColumn(0);
      expect(notifications, 1);
      expect(controller.isCpuThinking, isTrue);

      controller.playHumanColumn(1);
      expect(notifications, 1);
      expect(controller.moves, 1);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifications, 2);
      expect(controller.moves, 2);

      // Enche a coluna 0 (já possui 2 fichas: linha 5 humano, linha 4 cpu)
      for (var i = 0; i < 2; i++) {
        controller.playHumanColumn(0);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(BoardEngine.dropRow(controller.board, 0), -1);

      final beforeFullTap = notifications;
      controller.playHumanColumn(0);
      expect(notifications, beforeFullTap);
    });

    test('newGame cancela jogada pendente da CPU durante o delay', () async {
      final ai = _ScriptedCpuAi([4]);
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: const Duration(milliseconds: 30),
      );
      addTearDown(controller.dispose);

      controller.playHumanColumn(3);
      expect(controller.isCpuThinking, isTrue);

      controller.newGame();
      expect(controller.isCpuThinking, isFalse);
      expect(controller.moves, 0);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(ai.calls, 0);
      expect(controller.moves, 0);
      expect(controller.board.every((c) => c == Player.none), isTrue);
    });

    test('newGame descarta jogada da CPU se IA já estiver calculando (await)', () async {
      final ai = _CompleterCpuAi();
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      controller.playHumanColumn(3);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ai.calls, 1);
      expect(ai.pendingCompleter, isNotNull);

      controller.newGame();
      expect(controller.moves, 0);
      expect(controller.isCpuThinking, isFalse);

      // Resposta atrasada da partida anterior não pode sujar o novo tabuleiro
      ai.pendingCompleter!.complete(4);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.moves, 0);
      expect(controller.board.every((c) => c == Player.none), isTrue);
    });

    test('contabiliza vitória do humano, preserva placar em newGame e zera em resetScore', () async {
      final ai = _ScriptedCpuAi([6, 6, 6]);
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      for (var col = 0; col < 3; col++) {
        controller.playHumanColumn(col);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      // 4ª ficha do humano vence imediatamente sem acionar a CPU
      controller.playHumanColumn(3);

      expect(controller.isGameOver, isTrue);
      expect(controller.isCpuThinking, isFalse);
      expect(controller.winner, Player.human);
      expect(controller.winCells, {35, 36, 37, 38});
      expect(controller.humanWins, 1);
      expect(controller.cpuWins, 0);
      expect(controller.draws, 0);
      expect(ai.calls, 3);

      // Cliques após fim da partida são ignorados
      controller.playHumanColumn(4);
      expect(controller.moves, 7);

      // Nova partida preserva placar
      controller.newGame();
      expect(controller.humanWins, 1);
      expect(controller.isGameOver, isFalse);
      expect(controller.moves, 0);

      // Zerar placar limpa contadores e tabuleiro
      controller.resetScore();
      expect(controller.humanWins, 0);
      expect(controller.cpuWins, 0);
      expect(controller.draws, 0);
    });

    test('contabiliza vitória da CPU no placar', () async {
      final ai = _ScriptedCpuAi([6, 6, 6, 6]);
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.playHumanColumn(0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      controller.playHumanColumn(1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      controller.playHumanColumn(0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      controller.playHumanColumn(2);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.isGameOver, isTrue);
      expect(controller.winner, Player.cpu);
      expect(controller.cpuWins, 1);
      expect(controller.humanWins, 0);
      expect(controller.winCells.length, 4);
    });

    test('contabiliza empate quando os 42 espaços são preenchidos sem vencedor', () async {
      // Tabuleiro sem 4-em-linha: linhas 0..2 humano nas colunas pares / cpu nas ímpares,
      // linhas 3..5 humano nas colunas ímpares / cpu nas pares.
      final humanMoves = <int>[];
      final cpuMoves = <int>[];
      for (var r = 5; r >= 0; r--) {
        for (var c = 0; c < 7; c++) {
          final isHuman = r < 3 ? c.isEven : c.isOdd;
          if (isHuman) {
            humanMoves.add(c);
          } else {
            cpuMoves.add(c);
          }
        }
      }

      final ai = _ScriptedCpuAi(cpuMoves);
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: Duration.zero,
      );
      addTearDown(controller.dispose);

      for (final humanCol in humanMoves) {
        controller.playHumanColumn(humanCol);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(controller.moves, 42);
      expect(controller.isGameOver, isTrue);
      expect(controller.winner, Player.none);
      expect(controller.draws, 1);
      expect(controller.humanWins, 0);
      expect(controller.cpuWins, 0);
    });

    test('setDifficulty atualiza dificuldade e notifica apenas quando muda', () {
      final controller = GameController(ai: _ScriptedCpuAi([3]));
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setDifficulty(CpuDifficulty.medium);
      expect(notifications, 0);

      controller.setDifficulty(CpuDifficulty.hard);
      expect(controller.difficulty, CpuDifficulty.hard);
      expect(notifications, 1);
    });

    testWidgets('persiste em background e retoma turno pendente da CPU', (tester) async {
      final storage = _MemoryGameStorage();
      final firstController = GameController(
        ai: _ScriptedCpuAi([2]),
        cpuMoveDelay: const Duration(seconds: 1),
        storage: storage,
      );
      var firstControllerDisposed = false;
      addTearDown(() {
        if (!firstControllerDisposed) firstController.dispose();
      });
      await firstController.initialize();

      firstController.setDifficulty(CpuDifficulty.hard);
      firstController.playHumanColumn(3);
      expect(firstController.isCpuThinking, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(storage.snapshot, isNotNull);
      expect(storage.snapshot!.board[BoardEngine.indexOf(5, 3)], Player.human);
      expect(storage.snapshot!.isCpuTurnPending, isTrue);
      expect(storage.snapshot!.difficulty, CpuDifficulty.hard);

      firstController.dispose();
      firstControllerDisposed = true;
      final resumedAi = _ScriptedCpuAi([2]);
      final restoredController = GameController(ai: resumedAi, cpuMoveDelay: Duration.zero, storage: storage);
      addTearDown(restoredController.dispose);
      await restoredController.initialize();

      expect(restoredController.isCpuThinking, isTrue);
      expect(restoredController.difficulty, CpuDifficulty.hard);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(resumedAi.calls, 1);
      expect(restoredController.isCpuThinking, isFalse);
      expect(restoredController.board[BoardEngine.indexOf(5, 2)], Player.cpu);
      expect(restoredController.moves, 2);
    });

    testWidgets('restaura placar e dificuldade salvos', (tester) async {
      final storage = _MemoryGameStorage()
        ..snapshot = GameSnapshot(
          board: BoardEngine.createEmptyBoard(),
          isGameOver: false,
          isCpuTurnPending: false,
          winner: Player.none,
          winCells: const {},
          moves: 0,
          humanWins: 4,
          cpuWins: 2,
          draws: 1,
          difficulty: CpuDifficulty.hard,
        );
      final controller = GameController(storage: storage);
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.humanWins, 4);
      expect(controller.cpuWins, 2);
      expect(controller.draws, 1);
      expect(controller.difficulty, CpuDifficulty.hard);
    });

    test('não notifica nem agenda CPU se dispose ocorrer durante initialize', () async {
      final completer = Completer<GameSnapshot?>();
      final storage = _PendingLoadStorage(completer);
      final ai = _ScriptedCpuAi([3]);
      final controller = GameController(
        ai: ai,
        cpuMoveDelay: Duration.zero,
        storage: storage,
      );

      var notifications = 0;
      controller.addListener(() => notifications++);

      final initFuture = controller.initialize();
      controller.dispose();

      completer.complete(
        GameSnapshot(
          board: BoardEngine.createEmptyBoard(),
          isGameOver: false,
          isCpuTurnPending: true,
          winner: Player.none,
          winCells: const {},
          moves: 0,
          humanWins: 1,
          cpuWins: 0,
          draws: 0,
          difficulty: CpuDifficulty.medium,
        ),
      );

      await initFuture;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifications, 0);
      expect(ai.calls, 0);
    });
  });
}

class _PendingLoadStorage extends GameStorageService {
  _PendingLoadStorage(this.completer);

  final Completer<GameSnapshot?> completer;

  @override
  Future<GameSnapshot?> loadSnapshot() => completer.future;

  @override
  Future<void> saveSnapshot(GameSnapshot snapshot) async {}
}
