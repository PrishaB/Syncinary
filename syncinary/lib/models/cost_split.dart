/// Allocates whole units proportionally, assigning leftover units by largest
/// remainder so percentages and dollar cents always add up exactly.
List<int> allocateUnits(int total, List<int> weights) {
  if (weights.isEmpty) return [];
  final sum = weights.fold(0, (a, b) => a + b);
  final effective = sum == 0 ? List.filled(weights.length, 1) : weights;
  final divisor = sum == 0 ? weights.length : sum;
  final result = effective.map((w) => total * w ~/ divisor).toList();
  final order = List.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final comparison = (total * effective[b] % divisor).compareTo(
        total * effective[a] % divisor,
      );
      return comparison == 0 ? a.compareTo(b) : comparison;
    });
  final remaining = total - result.fold(0, (a, b) => a + b);
  for (var i = 0; i < remaining; i++) {
    result[order[i]]++;
  }
  return result;
}

List<int> adjustCostShares(List<int> shares, int index, int percentage) {
  if (shares.length == 1) return [100];
  final others = [...shares]..removeAt(index);
  final result = allocateUnits(100 - percentage, others);
  result.insert(index, percentage);
  return result;
}
