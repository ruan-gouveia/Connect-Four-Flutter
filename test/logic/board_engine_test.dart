import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/models/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Player', () {
    test('deve mapear códigos corretamente e retornar none para inválidos', () {
      expect(Player.none.code, 0);
      expect(Player.human.code, 1);
      expect(Player.cpu.code, 2);

      expect(Player.fromCode(0), Player.none);
      expect(Player.fromCode(1), Player.human);
      expect(Player.fromCode(2), Player.cpu);
      expect(Player.fromCode(-1), Player.none);
      expect(Player.fromCode(99), Player.none);
    });
  });

  group('BoardEngine', () {
    test('deve criar tabuleiro vazio com 42 espaços (6 linhas x 7 colunas)', () {
      final board = BoardEngine.createEmptyBoard();
      expect(board.length, 42);
      expect(board.every((cell) => cell == Player.none), isTrue);
      expect(BoardEngine.isBoardFull(board), isFalse);
      expect(BoardEngine.winningLine(board), isNull);
      expect(BoardEngine.winnerOf(board), Player.none);
    });

    test('deve pré-computar exatamente as 69 janelas de 4 casas no grid 7x6', () {
      expect(BoardEngine.windows.length, 69);
      for (final window in BoardEngine.windows) {
        expect(window.length, 4);
        expect(window.toSet().length, 4);
        for (final idx in window) {
          expect(idx, inInclusiveRange(0, 41));
        }
      }
    });

    test('dropRow deve posicionar na linha mais baixa (5..0) e -1 se cheia ou inválida', () {
      final board = BoardEngine.createEmptyBoard();

      expect(BoardEngine.dropRow(board, -1), -1);
      expect(BoardEngine.dropRow(board, 7), -1);

      for (int expectedRow = 5; expectedRow >= 0; expectedRow--) {
        final row = BoardEngine.dropRow(board, 3);
        expect(row, expectedRow);
        board[BoardEngine.indexOf(row, 3)] =
            expectedRow.isOdd ? Player.human : Player.cpu;
      }

      // Coluna 3 cheia -> retorna -1, enquanto coluna 0 continua livre na base (5)
      expect(BoardEngine.dropRow(board, 3), -1);
      expect(BoardEngine.dropRow(board, 0), 5);
    });

    test('deve detectar vitória horizontal na base e retornar os 4 índices', () {
      final board = BoardEngine.createEmptyBoard();
      // Reproduz alinhamento horizontal na linha 5, colunas 0..3 (CPU)
      for (int c = 0; c < 4; c++) {
        final row = BoardEngine.dropRow(board, c);
        expect(row, 5);
        board[BoardEngine.indexOf(row, c)] = Player.cpu;
      }

      expect(BoardEngine.winningLine(board), [35, 36, 37, 38]);
      expect(BoardEngine.winnerOf(board), Player.cpu);
      expect(BoardEngine.isDraw(board), isFalse);
    });

    test('deve detectar vitória vertical e retornar os 4 índices', () {
      final board = BoardEngine.createEmptyBoard();
      for (int i = 0; i < 4; i++) {
        final row = BoardEngine.dropRow(board, 4);
        board[BoardEngine.indexOf(row, 4)] = Player.human;
      }

      // Linhas 2, 3, 4, 5 da coluna 4 -> índices 18, 25, 32, 39
      expect(BoardEngine.winningLine(board), [18, 25, 32, 39]);
      expect(BoardEngine.winnerOf(board), Player.human);
    });

    test('deve detectar vitória na diagonal principal (\\)', () {
      final board = BoardEngine.createEmptyBoard();
      // Alinhamento diagonal (2,2), (3,3), (4,4), (5,5) da CPU
      board[BoardEngine.indexOf(2, 2)] = Player.cpu;
      board[BoardEngine.indexOf(3, 3)] = Player.cpu;
      board[BoardEngine.indexOf(4, 4)] = Player.cpu;
      board[BoardEngine.indexOf(5, 5)] = Player.cpu;

      expect(BoardEngine.winningLine(board), [16, 24, 32, 40]);
      expect(BoardEngine.winnerOf(board), Player.cpu);
    });

    test('deve detectar vitória na diagonal secundária (/)', () {
      final board = BoardEngine.createEmptyBoard();
      // Alinhamento diagonal ascendente (5,1), (4,2), (3,3), (2,4) do humano
      board[BoardEngine.indexOf(5, 1)] = Player.human;
      board[BoardEngine.indexOf(4, 2)] = Player.human;
      board[BoardEngine.indexOf(3, 3)] = Player.human;
      board[BoardEngine.indexOf(2, 4)] = Player.human;

      expect(BoardEngine.winningLine(board), [36, 30, 24, 18]);
      expect(BoardEngine.winnerOf(board), Player.human);
    });

    test('deve detectar empate ao preencher os 42 espaços sem 4 em linha', () {
      final board = BoardEngine.createEmptyBoard();
      int humanCount = 0;
      int cpuCount = 0;

      // Padrão válido 7x6: 21 fichas humanas + 21 CPU sem nenhum alinhamento de 4
      for (int r = 0; r < BoardEngine.rows; r++) {
        for (int c = 0; c < BoardEngine.cols; c++) {
          final isUpperHalf = r < 3;
          final isHuman = isUpperHalf ? c.isEven : c.isOdd;
          final player = isHuman ? Player.human : Player.cpu;
          board[BoardEngine.indexOf(r, c)] = player;
          if (isHuman) {
            humanCount++;
          } else {
            cpuCount++;
          }
        }
      }

      expect(humanCount, 21);
      expect(cpuCount, 21);
      expect(BoardEngine.isBoardFull(board), isTrue);
      expect(BoardEngine.winningLine(board), isNull);
      expect(BoardEngine.winnerOf(board), Player.none);
      expect(BoardEngine.isDraw(board), isTrue);

      for (int c = 0; c < BoardEngine.cols; c++) {
        expect(BoardEngine.dropRow(board, c), -1);
      }
    });
  });
}
