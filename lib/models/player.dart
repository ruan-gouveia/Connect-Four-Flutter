/// Representa o estado de ocupação de uma casa do tabuleiro de Lig 4.
enum Player {
  none(0),
  human(1), // Jogador humano (Vermelho - inicia a partida)
  cpu(2); // CPU (Azul)

  const Player(this.code);

  /// Código numérico usado para serialização e persistência.
  final int code;

  /// Converte um código numérico para o respectivo [Player].
  static Player fromCode(int code) {
    return Player.values.firstWhere(
      (p) => p.code == code,
      orElse: () => Player.none,
    );
  }
}
