import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:connect_four_flutter/core/constants/game_constants.dart';
import 'package:connect_four_flutter/logic/board_engine.dart';
import 'package:connect_four_flutter/logic/cpu_ai.dart';
import 'package:connect_four_flutter/models/cpu_difficulty.dart';
import 'package:connect_four_flutter/models/game_state.dart';
import 'package:connect_four_flutter/models/player.dart';
import 'package:connect_four_flutter/services/game_storage_service.dart';

/// Controlador central de estado da partida de Lig 4 (humano vs CPU).
class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController({
    CpuAi? ai,
    Duration? cpuMoveDelay,
    GameStorageService? storage,
  }) : _ai = ai ?? CpuAi(),
       _cpuMoveDelay = cpuMoveDelay ?? GameConstants.cpuMoveDelay,
       _storage = storage ?? GameStorageService();

  final CpuAi _ai;
  final Duration _cpuMoveDelay;
  final GameStorageService _storage;

  List<Player> _board = BoardEngine.createEmptyBoard();
  bool _isGameOver = false;
  bool _isCpuThinking = false;
  Player _winner = Player.none;
  Set<int> _winCells = const {};
  int _moves = 0;
  int _lastMoveIndex = -1;
  int _cpuTurnId = 0;

  int _humanWins = 0;
  int _cpuWins = 0;
  int _draws = 0;
  CpuDifficulty _difficulty = CpuDifficulty.medium;
  Timer? _cpuTurnTimer;
  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _isRestoring = false;
  Future<void>? _initialization;
  Future<void> _saveQueue = Future<void>.value();

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

  /// Restaura a partida salva e observa as mudanças de ciclo de vida do app.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_isInitialized || _isDisposed) return;
    _isInitialized = true;
    _isRestoring = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      final snapshot = await _storage.loadSnapshot();
      if (_isDisposed) return;
      if (snapshot != null) {
        _restoreSnapshot(snapshot);
        notifyListeners();
      }
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'game controller persistence',
          context: ErrorDescription('while restoring the saved game'),
        ),
      );
    } finally {
      _isRestoring = false;
    }

    if (_isDisposed) return;
    if (_isCpuThinking &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden) {
      _scheduleCpuTurn();
    }
  }

  void _restoreSnapshot(GameSnapshot snapshot) {
    _board = List<Player>.of(snapshot.board);
    _isGameOver = snapshot.isGameOver;
    _isCpuThinking = snapshot.isCpuTurnPending && !_isGameOver;
    _winner = snapshot.winner;
    _winCells = Set<int>.unmodifiable(snapshot.winCells);
    _moves = snapshot.moves;
    _humanWins = snapshot.humanWins;
    _cpuWins = snapshot.cpuWins;
    _draws = snapshot.draws;
    _difficulty = snapshot.difficulty;
    _lastMoveIndex = snapshot.lastMoveIndex;
  }

  GameSnapshot _createSnapshot() => GameSnapshot(
    board: _board,
    isGameOver: _isGameOver,
    isCpuTurnPending: _isCpuThinking,
    winner: _winner,
    winCells: _winCells,
    moves: _moves,
    humanWins: _humanWins,
    cpuWins: _cpuWins,
    draws: _draws,
    difficulty: _difficulty,
    lastMoveIndex: _lastMoveIndex,
  );

  void _queueSnapshotSave() {
    final snapshot = _createSnapshot();
    _saveQueue = _saveQueue
        .then((_) => _storage.saveSnapshot(snapshot))
        .catchError((Object error, StackTrace stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'game controller persistence',
              context: ErrorDescription('while saving the current game'),
            ),
          );
        });
  }

  void _notifyAndPersist() {
    notifyListeners();
    if (_isInitialized && !_isRestoring && !_isDisposed) {
      _queueSnapshotSave();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _cpuTurnTimer?.cancel();
      _cpuTurnTimer = null;
      _cpuTurnId++;
      if (_isInitialized && !_isRestoring) _queueSnapshotSave();
      return;
    }

    if (state == AppLifecycleState.resumed && _isCpuThinking && !_isGameOver) {
      _scheduleCpuTurn();
    }
  }

  /// Altera a dificuldade da CPU e notifica ouvintes apenas quando há mudança.
  void setDifficulty(CpuDifficulty newDifficulty) {
    if (_difficulty == newDifficulty) return;
    _difficulty = newDifficulty;
    _notifyAndPersist();
  }

  /// Registra a jogada do jogador humano (vermelho) na coluna [col].
  void playHumanColumn(int col) {
    if (_isRestoring || _isGameOver || _isCpuThinking) return;
    final row = BoardEngine.dropRow(_board, col);
    if (row < 0) return;

    _placeDisc(row, col, Player.human);
    if (!_isGameOver) {
      _isCpuThinking = true;
    }
    _notifyAndPersist();

    if (_isCpuThinking) {
      _scheduleCpuTurn();
    }
  }

  void _scheduleCpuTurn() {
    _cpuTurnTimer?.cancel();
    final scheduledTurnId = ++_cpuTurnId;
    _cpuTurnTimer = Timer(_cpuMoveDelay, () {
      _cpuTurnTimer = null;
      if (_isDisposed || scheduledTurnId != _cpuTurnId || !_isCpuThinking) {
        return;
      }
      unawaited(_executeCpuMove(scheduledTurnId));
    });
  }

  Future<void> _executeCpuMove(int scheduledTurnId) async {
    late final int col;
    try {
      col = await _ai.chooseMove(
        List<Player>.unmodifiable(_board),
        _difficulty,
      );
    } catch (error, stackTrace) {
      if (_isDisposed || scheduledTurnId != _cpuTurnId) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'game controller',
          context: ErrorDescription('while calculating the CPU move'),
        ),
      );
      _queueSnapshotSave();
      return;
    }
    if (_isDisposed || scheduledTurnId != _cpuTurnId || !_isCpuThinking) {
      return;
    }

    final row = col < 0 ? -1 : BoardEngine.dropRow(_board, col);
    if (row >= 0) {
      _placeDisc(row, col, Player.cpu);
    }
    _isCpuThinking = false;
    _notifyAndPersist();
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
    _cpuTurnId++;
    _board = BoardEngine.createEmptyBoard();
    _isGameOver = false;
    _isCpuThinking = false;
    _winner = Player.none;
    _winCells = const {};
    _moves = 0;
    _lastMoveIndex = -1;
    _notifyAndPersist();
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
    if (_isInitialized) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
