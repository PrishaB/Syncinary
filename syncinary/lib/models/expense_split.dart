/// The members responsible for one expense, optionally with custom percentages.
/// A null percentage map means an equal split, including older saved expenses.
class ExpenseSplit {
  ExpenseSplit({
    required List<String> splitWith,
    Map<String, double>? percentages,
  }) : splitWith = List.unmodifiable(splitWith),
       percentages = percentages == null ? null : Map.unmodifiable(percentages);

  final List<String> splitWith;
  final Map<String, double>? percentages;

  String? get validationError {
    if (splitWith.isEmpty ||
        splitWith.any((id) => id.isEmpty) ||
        splitWith.toSet().length != splitWith.length) {
      return 'Select at least one member, without duplicates.';
    }
    final custom = percentages;
    if (custom == null) return null;
    if (custom.length != splitWith.length ||
        !splitWith.every(custom.containsKey)) {
      return 'Enter a percentage for every selected member.';
    }
    if (custom.values.any(
      (value) => !value.isFinite || value < 0 || value > 100,
    )) {
      return 'Enter percentages between 0 and 100.';
    }
    final total = custom.values.fold<double>(0, (sum, value) => sum + value);
    if ((total - 100).abs() > 0.000001) {
      return 'Percentages must total 100%.';
    }
    return null;
  }

  Map<String, double> get percentagesByMember =>
      percentages ?? {for (final id in splitWith) id: 100 / splitWith.length};

  /// Allocates whole cents, distributing leftover cents by largest fractional
  /// share. Ties follow member order so the preview and saved totals agree.
  Map<String, double> amountsFor(double amount) {
    final error = validationError;
    if (error != null) throw ArgumentError(error);
    if (!amount.isFinite || amount < 0 || !(amount * 100).isFinite) {
      throw ArgumentError.value(amount, 'amount', 'Enter a valid cost.');
    }
    final totalCents = (amount * 100).round();
    final weights = percentagesByMember;
    final totalWeight = weights.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final exact = [
      for (final id in splitWith) totalCents * (weights[id]! / totalWeight),
    ];
    final cents = [for (final share in exact) share.floor()];
    final remainder =
        totalCents - cents.fold<int>(0, (sum, value) => sum + value);
    final order = List.generate(splitWith.length, (index) => index)
      ..sort((a, b) {
        final comparison = (exact[b] - cents[b]).compareTo(exact[a] - cents[a]);
        return comparison == 0 ? a.compareTo(b) : comparison;
      });
    for (var i = 0; i < remainder; i++) {
      cents[order[i % order.length]]++;
    }
    return {
      for (var i = 0; i < splitWith.length; i++) splitWith[i]: cents[i] / 100,
    };
  }
}
