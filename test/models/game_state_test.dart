import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/game_state.dart';
import 'package:connect_four_flutter/models/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameSnapshot', () {
    test('round-trips board, pending CPU turn, score, and difficulty', () {
      final board = BoardEngine.createEmptyBoard();
      board[BoardEngine.indexOf(5, 3)] = Player.human;
      final snapshot = GameSnapshot(
        board: board,
        isGameOver: false,
        isCpuTurnPending: true,
        winner: Player.none,
        winCells: const {},
        moves: 1,
        humanWins: 2,
        cpuWins: 1,
        draws: 3,
        difficulty: CpuDifficulty.hard,
        lastMoveIndex: BoardEngine.indexOf(5, 3),
      );

      final restored = GameSnapshot.fromJsonString(snapshot.toJsonString());

      expect(restored.board, snapshot.board);
      expect(restored.isCpuTurnPending, isTrue);
      expect(restored.winner, Player.none);
      expect(restored.moves, 1);
      expect(restored.humanWins, 2);
      expect(restored.cpuWins, 1);
      expect(restored.draws, 3);
      expect(restored.difficulty, CpuDifficulty.hard);
      expect(restored.lastMoveIndex, BoardEngine.indexOf(5, 3));
    });

    test('rejects malformed or invalid board data', () {
      expect(
        () => GameSnapshot.fromJsonString('not json'),
        throwsFormatException,
      );
      expect(
        () => GameSnapshot.fromJsonString('{"board": []}'),
        throwsFormatException,
      );
    });
  });
}
