import 'package:connect_four_flutter/core/constants/game_constants.dart';
import 'package:connect_four_flutter/models/player.dart';

/// Motor puro das regras do tabuleiro 7x6 do Lig 4 (gravidade, vitória e empate).
class BoardEngine {
  const BoardEngine._();

  static const int rows = GameConstants.rows;
  static const int cols = GameConstants.cols;
  static const int totalCells = GameConstants.totalCells;
  static const int winLength = GameConstants.winLength;

  /// Converte coordenadas (linha, coluna) para o índice linear do tabuleiro.
  static int indexOf(int row, int col) => row * cols + col;

  /// Cria um tabuleiro vazio com 42 espaços (índice = row * cols + col).
  static List<Player> createEmptyBoard() =>
      List<Player>.filled(totalCells, Player.none);

  /// Retorna a linha mais baixa livre na coluna [col], ou -1 se inválida ou cheia.
  static int dropRow(List<Player> board, int col) {
    if (col < 0 || col >= cols) return -1;
    for (int r = rows - 1; r >= 0; r--) {
      if (board[indexOf(r, col)] == Player.none) return r;
    }
    return -1;
  }

  /// Todas as 69 janelas de 4 casas (horizontal, vertical e diagonais).
  static final List<List<int>> windows = _buildWindows();

  static List<List<int>> _buildWindows() {
    final result = <List<int>>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Horizontal (->)
        if (c + winLength - 1 < cols) {
          result.add(
            List<int>.unmodifiable([
              for (int k = 0; k < winLength; k++) indexOf(r, c + k),
            ]),
          );
        }
        // Vertical (v)
        if (r + winLength - 1 < rows) {
          result.add(
            List<int>.unmodifiable([
              for (int k = 0; k < winLength; k++) indexOf(r + k, c),
            ]),
          );
        }
        // Diagonal descendente (\)
        if (r + winLength - 1 < rows && c + winLength - 1 < cols) {
          result.add(
            List<int>.unmodifiable([
              for (int k = 0; k < winLength; k++) indexOf(r + k, c + k),
            ]),
          );
        }
        // Diagonal ascendente (/)
        if (r - (winLength - 1) >= 0 && c + winLength - 1 < cols) {
          result.add(
            List<int>.unmodifiable([
              for (int k = 0; k < winLength; k++) indexOf(r - k, c + k),
            ]),
          );
        }
      }
    }
    return List<List<int>>.unmodifiable(result);
  }

  /// Devolve os 4 índices da linha vencedora, ou `null` se ninguém venceu.
  static List<int>? winningLine(List<Player> board) {
    for (final w in windows) {
      final first = board[w[0]];
      if (first != Player.none &&
          first == board[w[1]] &&
          first == board[w[2]] &&
          first == board[w[3]]) {
        return w;
      }
    }
    return null;
  }

  /// Retorna o jogador vencedor do tabuleiro atual, ou [Player.none].
  static Player winnerOf(List<Player> board) {
    final line = winningLine(board);
    return line == null ? Player.none : board[line[0]];
  }

  /// Verifica se todos os 42 espaços do tabuleiro já foram preenchidos.
  static bool isBoardFull(List<Player> board) {
    for (int i = 0; i < totalCells; i++) {
      if (board[i] == Player.none) return false;
    }
    return true;
  }

  /// Verifica se a partida terminou empatada (42 casas preenchidas sem vencedor).
  static bool isDraw(List<Player> board) {
    return winningLine(board) == null && isBoardFull(board);
  }
}
