class GameConstants {
  const GameConstants._();

  static const int rows = 6;
  static const int cols = 7;
  static const int totalCells = rows * cols; // 42 espaços
  static const int winLength = 4;

  static const Duration cpuMoveDelay = Duration(milliseconds: 700);
  static const int baseDropDurationMs = 280;
  static const int perRowDropDurationMs = 40;
}
