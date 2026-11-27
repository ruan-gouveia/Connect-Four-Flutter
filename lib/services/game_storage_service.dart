import 'package:connect_four_flutter/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameStorageService {
  static const String _snapshotKey = 'lig4_active_game_snapshot_v1';

  Future<void> saveSnapshot(GameSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _snapshotKey,
      snapshot.toJsonString(),
    );
    if (!saved) {
      throw StateError('Could not persist the active game snapshot.');
    }
  }

  Future<GameSnapshot?> loadSnapshot() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) return null;
    return GameSnapshot.fromJsonString(raw);
  }
}
