import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute, kIsWeb;

import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/player.dart';

class CpuAi {
  CpuAi({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  static const List<int> _columnOrder = [3, 2, 4, 1, 5, 0, 6];
  static const int _minScore = -(1 << 30);
  static const int _maxScore = 1 << 30;
  static const int _winScore = 1000000;
  // Keep each browser task short enough to allow frames and input events.
  static const int _webYieldInterval = 64;

  Future<int> chooseMove(List<Player> board, CpuDifficulty difficulty) async {
    if (BoardEngine.winnerOf(board) != Player.none) return -1;

    final validCols = [
      for (final col in _columnOrder)
        if (BoardEngine.dropRow(board, col) >= 0) col,
    ];
    if (validCols.isEmpty) return -1;

    if (difficulty.randomChance > 0 &&
        _random.nextDouble() < difficulty.randomChance) {
      return validCols[_random.nextInt(validCols.length)];
    }

    // Flutter's compute callback runs on the main event loop on the Web.
    if (kIsWeb) {
      return _chooseMoveOnWeb(board, difficulty.depth);
    }

    return compute(
      _chooseMoveInIsolate,
      _CpuMoveRequest(
        board.map((player) => player.code).toList(growable: false),
        difficulty.depth,
      ),
      debugLabel: 'connect-four-cpu-ai',
    );
  }

  int _chooseBestMove(List<Player> board, int depth) {
    final workingBoard = List<Player>.of(board);
    var bestCol = -1;
    var bestScore = _minScore;
    var alpha = _minScore;

    for (final col in _columnOrder) {
      final row = BoardEngine.dropRow(workingBoard, col);
      if (row < 0) continue;
      final index = BoardEngine.indexOf(row, col);
      workingBoard[index] = Player.cpu;
      final score = _minimax(workingBoard, depth - 1, alpha, _maxScore, false);
      workingBoard[index] = Player.none;

      if (score > bestScore) {
        bestScore = score;
        bestCol = col;
      }
      alpha = math.max(alpha, bestScore);
    }

    return bestCol;
  }

  Future<int> _chooseMoveOnWeb(List<Player> board, int depth) async {
    final workingBoard = List<Player>.of(board);
    final progress = _SearchProgress();
    var bestCol = -1;
    var bestScore = _minScore;
    var alpha = _minScore;

    for (final col in _columnOrder) {
      final row = BoardEngine.dropRow(workingBoard, col);
      if (row < 0) continue;

      final index = BoardEngine.indexOf(row, col);
      workingBoard[index] = Player.cpu;
      final score = await _minimaxOnWeb(
        workingBoard,
        depth - 1,
        alpha,
        _maxScore,
        false,
        progress,
      );
      workingBoard[index] = Player.none;

      if (score > bestScore) {
        bestScore = score;
        bestCol = col;
      }
      alpha = math.max(alpha, bestScore);
    }

    return bestCol;
  }

  int _minimax(
    List<Player> board,
    int depth,
    int alpha,
    int beta,
    bool isMaximizing,
  ) {
    final winner = BoardEngine.winnerOf(board);
    if (winner == Player.cpu) return _winScore + depth;
    if (winner == Player.human) return -_winScore - depth;
    if (depth <= 0) return _heuristic(board);

    var hasValidMoves = false;
    var bestScore = isMaximizing ? _minScore : _maxScore;

    for (final col in _columnOrder) {
      final row = BoardEngine.dropRow(board, col);
      if (row < 0) continue;
      hasValidMoves = true;

      final index = BoardEngine.indexOf(row, col);
      board[index] = isMaximizing ? Player.cpu : Player.human;
      final score = _minimax(board, depth - 1, alpha, beta, !isMaximizing);
      board[index] = Player.none;

      if (isMaximizing) {
        bestScore = math.max(bestScore, score);
        alpha = math.max(alpha, bestScore);
      } else {
        bestScore = math.min(bestScore, score);
        beta = math.min(beta, bestScore);
      }

      if (alpha >= beta) break;
    }

    return hasValidMoves ? bestScore : 0;
  }

  Future<int> _minimaxOnWeb(
    List<Player> board,
    int depth,
    int alpha,
    int beta,
    bool isMaximizing,
    _SearchProgress progress,
  ) async {
    progress.nodesSinceYield++;
    if (progress.nodesSinceYield >= _webYieldInterval) {
      progress.nodesSinceYield = 0;
      await Future<void>.delayed(Duration.zero);
    }

    final winner = BoardEngine.winnerOf(board);
    if (winner == Player.cpu) return _winScore + depth;
    if (winner == Player.human) return -_winScore - depth;
    if (depth <= 0) return _heuristic(board);

    var hasValidMoves = false;
    var bestScore = isMaximizing ? _minScore : _maxScore;

    for (final col in _columnOrder) {
      final row = BoardEngine.dropRow(board, col);
      if (row < 0) continue;
      hasValidMoves = true;

      final index = BoardEngine.indexOf(row, col);
      board[index] = isMaximizing ? Player.cpu : Player.human;
      final score = await _minimaxOnWeb(
        board,
        depth - 1,
        alpha,
        beta,
        !isMaximizing,
        progress,
      );
      board[index] = Player.none;

      if (isMaximizing) {
        bestScore = math.max(bestScore, score);
        alpha = math.max(alpha, bestScore);
      } else {
        bestScore = math.min(bestScore, score);
        beta = math.min(beta, bestScore);
      }

      if (alpha >= beta) break;
    }

    return hasValidMoves ? bestScore : 0;
  }

  int _heuristic(List<Player> board) {
    var score = 0;
    final centerColumn = BoardEngine.cols ~/ 2;

    for (var row = 0; row < BoardEngine.rows; row++) {
      final cell = board[BoardEngine.indexOf(row, centerColumn)];
      if (cell == Player.cpu) {
        score += 6;
      } else if (cell == Player.human) {
        score -= 6;
      }
    }

    for (final window in BoardEngine.windows) {
      var cpuCount = 0;
      var humanCount = 0;
      for (final index in window) {
        if (board[index] == Player.cpu) {
          cpuCount++;
        } else if (board[index] == Player.human) {
          humanCount++;
        }
      }

      if (humanCount == 0) {
        if (cpuCount == 3) score += 50;
        if (cpuCount == 2) score += 5;
      } else if (cpuCount == 0) {
        if (humanCount == 3) score -= 80;
        if (humanCount == 2) score -= 5;
      }
    }

    return score;
  }
}

class _CpuMoveRequest {
  const _CpuMoveRequest(this.board, this.depth);

  final List<int> board;
  final int depth;
}

class _SearchProgress {
  int nodesSinceYield = 0;
}

int _chooseMoveInIsolate(_CpuMoveRequest request) {
  final board = request.board.map(Player.fromCode).toList(growable: false);
  return CpuAi()._chooseBestMove(board, request.depth);
}
