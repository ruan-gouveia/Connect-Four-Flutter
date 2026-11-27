enum CpuDifficulty {
  easy(label: 'Fácil', depth: 2, randomChance: 0.45),
  medium(label: 'Médio', depth: 4, randomChance: 0.10),
  hard(label: 'Difícil', depth: 6, randomChance: 0.0);

  const CpuDifficulty({
    required this.label,
    required this.depth,
    required this.randomChance,
  });

  final String label;
  final int depth;
  final double randomChance;
}
