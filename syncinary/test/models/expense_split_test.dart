import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/expense_split.dart';

void main() {
  test(
    '[103-1] custom percentages allocate the item cost, including zero shares',
    () {
      final split = ExpenseSplit(
        splitWith: ['me', 'alex', 'sam'],
        percentages: {'me': 62.5, 'alex': 37.5, 'sam': 0},
      );
      expect(split.validationError, isNull);
      expect(split.amountsFor(80), {'me': 50, 'alex': 30, 'sam': 0});
    },
  );

  test(
    '[103-1] equal shares and fractional percentages preserve every cent',
    () {
      for (final count in [1, 2, 3, 4, 8]) {
        final ids = List.generate(count, (i) => 'member-$i');
        final split = ExpenseSplit(splitWith: ids);
        for (final amount in [0.01, 0.02, 10.0, 10.01, 123.45]) {
          final cents = split
              .amountsFor(amount)
              .values
              .map((value) => (value * 100).round());
          expect(cents.reduce((a, b) => a + b), (amount * 100).round());
          expect(cents.every((value) => value >= 0), isTrue);
          expect(
            cents.reduce((a, b) => a > b ? a : b) -
                cents.reduce((a, b) => a < b ? a : b),
            lessThanOrEqualTo(1),
          );
        }
      }
      final thirds = ExpenseSplit(splitWith: ['a', 'b', 'c']);
      expect(thirds.amountsFor(10), {'a': 3.34, 'b': 3.33, 'c': 3.33});
      final custom = ExpenseSplit(
        splitWith: ['a', 'b', 'c'],
        percentages: {'a': 33.33, 'b': 33.33, 'c': 33.34},
      );
      expect(custom.amountsFor(10), {'a': 3.33, 'b': 3.33, 'c': 3.34});
      expect(custom.amountsFor(0.01), {'a': 0, 'b': 0, 'c': 0.01});
    },
  );

  test('[103-3] invalid allocations cannot produce amounts', () {
    final invalid = [
      ExpenseSplit(splitWith: []),
      ExpenseSplit(splitWith: ['a', 'a']),
      ExpenseSplit(splitWith: ['']),
      ExpenseSplit(splitWith: ['a', 'b'], percentages: {'a': 100}),
      ExpenseSplit(splitWith: ['a'], percentages: {'b': 100}),
      for (final values in <List<double>>[
        <double>[50, 40],
        [60, 50],
        [-1, 101],
        [0, 0],
        [double.nan, 100],
        [double.infinity, 0],
      ])
        ExpenseSplit(
          splitWith: ['a', 'b'],
          percentages: {'a': values[0], 'b': values[1]},
        ),
    ];
    for (final split in invalid) {
      expect(split.validationError, isNotNull);
      expect(() => split.amountsFor(100), throwsArgumentError);
    }
  });

  test('[103-2] a zero cost allocates zero to every member', () {
    expect(ExpenseSplit(splitWith: ['a', 'b']).amountsFor(0), {'a': 0, 'b': 0});
  });
}
