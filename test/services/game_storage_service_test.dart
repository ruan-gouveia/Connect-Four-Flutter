import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/game_state.dart';
import 'package:connect_four_flutter/models/player.dart';
import 'package:connect_four_flutter/services/game_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameStorageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and restores the active snapshot', () async {
      final board = BoardEngine.createEmptyBoard();
      board[BoardEngine.indexOf(5, 2)] = Player.human;
      final snapshot = GameSnapshot(
        board: board,
        isGameOver: false,
        isCpuTurnPending: true,
        winner: Player.none,
        winCells: const {},
        moves: 1,
        humanWins: 1,
        cpuWins: 2,
        draws: 0,
        difficulty: CpuDifficulty.medium,
      );
      final storage = GameStorageService();

      await storage.saveSnapshot(snapshot);
      final restored = await storage.loadSnapshot();

      expect(restored?.board, snapshot.board);
      expect(restored?.isCpuTurnPending, isTrue);
      expect(restored?.humanWins, 1);
      expect(restored?.cpuWins, 2);
      expect(restored?.difficulty, CpuDifficulty.medium);
    });

    test('returns null when no snapshot exists', () async {
      expect(await GameStorageService().loadSnapshot(), isNull);
    });

    test('reports corrupted stored snapshots', () async {
      SharedPreferences.setMockInitialValues({
        'lig4_active_game_snapshot_v1': 'invalid json',
      });

      expect(GameStorageService().loadSnapshot(), throwsFormatException);
    });
  });
}
