import 'dart:math' as math;

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

  int chooseMove(List<Player> board, CpuDifficulty difficulty) {
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

    final workingBoard = List<Player>.of(board);
    var bestCol = validCols.first;
    var bestScore = _minScore;
    var alpha = _minScore;

    for (final col in validCols) {
      final row = BoardEngine.dropRow(workingBoard, col);
      final index = BoardEngine.indexOf(row, col);
      workingBoard[index] = Player.cpu;
      final score = _minimax(
        workingBoard,
        difficulty.depth - 1,
        alpha,
        _maxScore,
        false,
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
