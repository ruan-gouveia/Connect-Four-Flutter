import 'dart:convert';

import 'package:connect_four_flutter/core/constants/game_constants.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/player.dart';

class GameSnapshot {
  GameSnapshot({
    required List<Player> board,
    required this.isGameOver,
    required this.isCpuTurnPending,
    required this.winner,
    required Set<int> winCells,
    required this.moves,
    required this.humanWins,
    required this.cpuWins,
    required this.draws,
    required this.difficulty,
    this.lastMoveIndex = -1,
  }) : board = List<Player>.unmodifiable(board),
       winCells = Set<int>.unmodifiable(winCells);

  final List<Player> board;
  final bool isGameOver;
  final bool isCpuTurnPending;
  final Player winner;
  final Set<int> winCells;
  final int moves;
  final int humanWins;
  final int cpuWins;
  final int draws;
  final CpuDifficulty difficulty;
  final int lastMoveIndex;

  String toJsonString() => jsonEncode({
    'board': board.map((player) => player.code).toList(),
    'isGameOver': isGameOver,
    'isCpuTurnPending': isCpuTurnPending,
    'winner': winner.code,
    'winCells': winCells.toList(),
    'moves': moves,
    'humanWins': humanWins,
    'cpuWins': cpuWins,
    'draws': draws,
    'difficulty': difficulty.name,
    'lastMoveIndex': lastMoveIndex,
  });

  factory GameSnapshot.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Game snapshot must be a JSON object.');
    }

    final rawBoard = decoded['board'];
    if (rawBoard is! List || rawBoard.length != GameConstants.totalCells) {
      throw FormatException(
        'Game snapshot board must contain ${GameConstants.totalCells} cells.',
      );
    }
    final board = rawBoard
        .map((value) {
          if (value is! int ||
              !Player.values.any((player) => player.code == value)) {
            throw const FormatException(
              'Game snapshot contains an invalid cell.',
            );
          }
          return Player.fromCode(value);
        })
        .toList(growable: false);

    final rawWinCells = decoded['winCells'] ?? const <Object>[];
    if (rawWinCells is! List ||
        rawWinCells.any(
          (value) => value is! int || value < 0 || value >= board.length,
        )) {
      throw const FormatException('Game snapshot contains invalid win cells.');
    }

    final winnerCode = _readInt(decoded, 'winner', fallback: Player.none.code);
    if (!Player.values.any((player) => player.code == winnerCode)) {
      throw const FormatException('Game snapshot contains an invalid winner.');
    }

    final difficultyName = decoded['difficulty'];
    final difficulty = difficultyName == null
        ? CpuDifficulty.medium
        : CpuDifficulty.values.firstWhere(
            (value) => value.name == difficultyName,
            orElse: () =>
                throw const FormatException('Invalid CPU difficulty.'),
          );
    final moves = _readInt(
      decoded,
      'moves',
      fallback: board.where((player) => player != Player.none).length,
    );
    final lastMoveIndex = _readInt(decoded, 'lastMoveIndex', fallback: -1);
    if (moves < 0 || moves > board.length) {
      throw const FormatException('Game snapshot contains invalid move count.');
    }
    if (moves != board.where((player) => player != Player.none).length) {
      throw const FormatException(
        'Game snapshot move count does not match the board.',
      );
    }
    if (lastMoveIndex < -1 || lastMoveIndex >= board.length) {
      throw const FormatException('Game snapshot contains invalid last move.');
    }
    if (lastMoveIndex >= 0 && board[lastMoveIndex] == Player.none) {
      throw const FormatException(
        'Game snapshot last move points to an empty cell.',
      );
    }

    return GameSnapshot(
      board: board,
      isGameOver: _readBool(decoded, 'isGameOver', fallback: false),
      isCpuTurnPending: _readBool(decoded, 'isCpuTurnPending', fallback: false),
      winner: Player.fromCode(winnerCode),
      winCells: rawWinCells.cast<int>().toSet(),
      moves: moves,
      humanWins: _readNonNegativeInt(decoded, 'humanWins'),
      cpuWins: _readNonNegativeInt(decoded, 'cpuWins'),
      draws: _readNonNegativeInt(decoded, 'draws'),
      difficulty: difficulty,
      lastMoveIndex: lastMoveIndex,
    );
  }
}

int _readInt(Map<String, dynamic> map, String key, {int? fallback}) {
  final value = map[key] ?? fallback;
  if (value is! int) {
    throw FormatException('Game snapshot field "$key" must be an integer.');
  }
  return value;
}

int _readNonNegativeInt(Map<String, dynamic> map, String key) {
  final value = _readInt(map, key, fallback: 0);
  if (value < 0) {
    throw FormatException('Game snapshot field "$key" cannot be negative.');
  }
  return value;
}

bool _readBool(Map<String, dynamic> map, String key, {required bool fallback}) {
  final value = map[key] ?? fallback;
  if (value is! bool) {
    throw FormatException('Game snapshot field "$key" must be a boolean.');
  }
  return value;
}
