import 'dart:async';
import 'dart:math' as math;

import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/logic/cpu_ai.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CpuDifficulty', () {
    test('define os níveis, profundidades e aleatoriedade esperados', () {
      expect(CpuDifficulty.easy.label, 'Fácil');
      expect(CpuDifficulty.easy.depth, 2);
      expect(CpuDifficulty.easy.randomChance, 0.45);
      expect(CpuDifficulty.medium.label, 'Médio');
      expect(CpuDifficulty.medium.depth, 4);
      expect(CpuDifficulty.medium.randomChance, 0.10);
      expect(CpuDifficulty.hard.label, 'Difícil');
      expect(CpuDifficulty.hard.depth, 6);
      expect(CpuDifficulty.hard.randomChance, 0);
    });
  });

  group('CpuAi', () {
    final ai = CpuAi();

    test('vence quando pode completar quatro fichas em um lance', () async {
      final board = BoardEngine.createEmptyBoard();
      _drop(board, 0, Player.cpu);
      _drop(board, 1, Player.cpu);
      _drop(board, 2, Player.cpu);
      final originalBoard = List<Player>.of(board);

      expect(await ai.chooseMove(board, CpuDifficulty.hard), 3);
      expect(board, originalBoard);
    });

    test(
      'bloqueia a vitória horizontal imediata do humano no modo difícil',
      () async {
        final board = BoardEngine.createEmptyBoard();
        _drop(board, 0, Player.human);
        _drop(board, 1, Player.human);
        _drop(board, 2, Player.human);

        expect(await ai.chooseMove(board, CpuDifficulty.hard), 3);
      },
    );

    test('bloqueia uma ameaça vertical imediata no modo difícil', () async {
      final board = BoardEngine.createEmptyBoard();
      _drop(board, 3, Player.human);
      _drop(board, 3, Player.human);
      _drop(board, 3, Player.human);

      expect(await ai.chooseMove(board, CpuDifficulty.hard), 3);
    });

    test('bloqueia uma ameaça diagonal imediata no modo difícil', () async {
      final board = BoardEngine.createEmptyBoard();
      _drop(board, 0, Player.human);
      _drop(board, 1, Player.cpu);
      _drop(board, 1, Player.human);
      _drop(board, 2, Player.cpu);
      _drop(board, 2, Player.cpu);
      _drop(board, 2, Player.human);
      _drop(board, 3, Player.human);
      _drop(board, 3, Player.cpu);
      _drop(board, 3, Player.cpu);

      expect(await ai.chooseMove(board, CpuDifficulty.hard), 3);
    });

    test('prioriza a coluna central em um tabuleiro vazio', () async {
      expect(
        await ai.chooseMove(BoardEngine.createEmptyBoard(), CpuDifficulty.hard),
        3,
      );
    });

    test('retorna -1 quando a partida já terminou', () async {
      final board = BoardEngine.createEmptyBoard();
      for (var col = 0; col < 4; col++) {
        _drop(board, col, Player.human);
      }

      expect(await ai.chooseMove(board, CpuDifficulty.hard), -1);
    });

    test('retorna -1 em empate sem colunas disponíveis', () async {
      final board = BoardEngine.createEmptyBoard();
      for (var row = 0; row < BoardEngine.rows; row++) {
        for (var col = 0; col < BoardEngine.cols; col++) {
          final isHuman = row < 3 ? col.isEven : col.isOdd;
          board[BoardEngine.indexOf(row, col)] = isHuman
              ? Player.human
              : Player.cpu;
        }
      }

      expect(BoardEngine.isDraw(board), isTrue);
      expect(await ai.chooseMove(board, CpuDifficulty.hard), -1);
    });

    test(
      'retorna somente uma coluna disponível nos níveis aleatórios',
      () async {
        final board = BoardEngine.createEmptyBoard();
        final availableColumns = <int>{0, 1, 2, 3, 4, 5, 6};
        final aiWithSeed = CpuAi(random: math.Random(0));

        for (final difficulty in [CpuDifficulty.easy, CpuDifficulty.medium]) {
          expect(
            availableColumns.contains(
              await aiWithSeed.chooseMove(board, difficulty),
            ),
            isTrue,
          );
        }
      },
    );

    test('cede o event loop durante a busca no modo difícil', () async {
      var eventLoopRan = false;
      Timer.run(() => eventLoopRan = true);

      final move = await ai.chooseMove(
        BoardEngine.createEmptyBoard(),
        CpuDifficulty.hard,
      );

      expect(move, 3);
      expect(eventLoopRan, isTrue);
    });
  });
}

void _drop(List<Player> board, int col, Player player) {
  final row = BoardEngine.dropRow(board, col);
  expect(row, greaterThanOrEqualTo(0));
  board[BoardEngine.indexOf(row, col)] = player;
}
