import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:connect_four_flutter/core/constants/game_constants.dart';
import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/logic/cpu_ai.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/player.dart';

/// Controlador central de estado da partida de Lig 4 (humano vs CPU).
class GameController extends ChangeNotifier {
  GameController({CpuAi? ai, Duration? cpuMoveDelay})
    : _ai = ai ?? CpuAi(),
      _cpuMoveDelay = cpuMoveDelay ?? GameConstants.cpuMoveDelay;

  final CpuAi _ai;
  final Duration _cpuMoveDelay;

  List<Player> _board = BoardEngine.createEmptyBoard();
  bool _isGameOver = false;
  bool _isCpuThinking = false;
  Player _winner = Player.none;
  Set<int> _winCells = const {};
  int _moves = 0;
  int _lastMoveIndex = -1;
  int _gameId = 0;

  int _humanWins = 0;
  int _cpuWins = 0;
  int _draws = 0;
  CpuDifficulty _difficulty = CpuDifficulty.medium;
  Timer? _cpuTurnTimer;
  bool _isDisposed = false;

  /// Estado atual das 42 casas do tabuleiro em ordem linear.
  List<Player> get board => List<Player>.unmodifiable(_board);

  bool get isGameOver => _isGameOver;
  bool get isCpuThinking => _isCpuThinking;
  Player get winner => _winner;
  Set<int> get winCells => _winCells;
  int get moves => _moves;
  int get lastMoveIndex => _lastMoveIndex;
  int get humanWins => _humanWins;
  int get cpuWins => _cpuWins;
  int get draws => _draws;
  CpuDifficulty get difficulty => _difficulty;

  /// Altera a dificuldade da CPU e notifica ouvintes apenas quando há mudança.
  void setDifficulty(CpuDifficulty newDifficulty) {
    if (_difficulty == newDifficulty) return;
    _difficulty = newDifficulty;
    notifyListeners();
  }

  /// Registra a jogada do jogador humano (vermelho) na coluna [col].
  void playHumanColumn(int col) {
    if (_isGameOver || _isCpuThinking) return;
    final row = BoardEngine.dropRow(_board, col);
    if (row < 0) return;

    _placeDisc(row, col, Player.human);
    if (!_isGameOver) {
      _isCpuThinking = true;
    }
    notifyListeners();

    if (_isCpuThinking) {
      _scheduleCpuTurn(_gameId);
    }
  }

  void _scheduleCpuTurn(int scheduledGameId) {
    _cpuTurnTimer?.cancel();
    _cpuTurnTimer = Timer(_cpuMoveDelay, () {
      _cpuTurnTimer = null;
      if (_isDisposed || scheduledGameId != _gameId || !_isCpuThinking) return;
      unawaited(_executeCpuMove(scheduledGameId));
    });
  }

  Future<void> _executeCpuMove(int scheduledGameId) async {
    final col = await _ai.chooseMove(
      List<Player>.unmodifiable(_board),
      _difficulty,
    );
    if (_isDisposed || scheduledGameId != _gameId || !_isCpuThinking) return;

    final row = col < 0 ? -1 : BoardEngine.dropRow(_board, col);
    if (row >= 0) {
      _placeDisc(row, col, Player.cpu);
    }
    _isCpuThinking = false;
    notifyListeners();
  }

  void _placeDisc(int row, int col, Player player) {
    final idx = BoardEngine.indexOf(row, col);
    _board[idx] = player;
    _lastMoveIndex = idx;
    _moves++;

    final line = BoardEngine.winningLine(_board);
    if (line != null) {
      _isGameOver = true;
      _winner = player;
      _winCells = Set<int>.unmodifiable(line);
      if (player == Player.human) {
        _humanWins++;
      } else {
        _cpuWins++;
      }
    } else if (_moves == GameConstants.totalCells) {
      _isGameOver = true;
      _draws++;
    }
  }

  /// Inicia uma nova partida preservando o placar acumulado (humano sempre inicia).
  void newGame() {
    _cpuTurnTimer?.cancel();
    _cpuTurnTimer = null;
    _gameId++;
    _board = BoardEngine.createEmptyBoard();
    _isGameOver = false;
    _isCpuThinking = false;
    _winner = Player.none;
    _winCells = const {};
    _moves = 0;
    _lastMoveIndex = -1;
    notifyListeners();
  }

  /// Reinicia o tabuleiro e zera vitórias e empates do placar.
  void resetScore() {
    _humanWins = 0;
    _cpuWins = 0;
    _draws = 0;
    newGame();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cpuTurnTimer?.cancel();
    _cpuTurnTimer = null;
    super.dispose();
  }
}
