import 'package:flutter/material.dart';
import '../models/expense_split.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';

enum _SplitChoice { justMe, evenly, custom }

/// Quick presets and per-member percentage inputs for a single expense.
class ExpenseSplitEditor extends StatefulWidget {
  const ExpenseSplitEditor({
    super.key,
    required this.members,
    required this.currentUserId,
    required this.value,
    required this.amount,
    required this.onChanged,
    this.enabled = true,
  });

  final List<GroupMember> members;
  final String currentUserId;
  final ExpenseSplit value;
  final double amount;
  final ValueChanged<ExpenseSplit> onChanged;
  final bool enabled;

  @override
  State<ExpenseSplitEditor> createState() => _ExpenseSplitEditorState();
}

class _ExpenseSplitEditorState extends State<ExpenseSplitEditor> {
  late _SplitChoice _choice = widget.value.percentages != null
      ? _SplitChoice.custom
      : widget.value.splitWith.length == 1 &&
            widget.value.splitWith.single == widget.currentUserId
      ? _SplitChoice.justMe
      : _SplitChoice.evenly;
  final _controllers = <String, TextEditingController>{};
  final _editedPercentageIds = <String>{};

  @override
  void initState() {
    super.initState();
    _seedPercentages();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seedPercentages() {
    _editedPercentageIds.clear();
    final selected = widget.value.splitWith;
    // Round the editable preset to hundredths of a percent, keeping exactly
    // 100% for three, six, or other non-divisible group sizes.
    final hundredths = selected.isEmpty ? 0 : 10000 ~/ selected.length;
    final remainder = selected.isEmpty ? 0 : 10000 % selected.length;
    for (final member in widget.members) {
      final index = selected.indexOf(member.id);
      final percent =
          widget.value.percentages?[member.id] ??
          (index < 0 ? 0.0 : (hundredths + (index < remainder ? 1 : 0)) / 100);
      final controller = _controllers.putIfAbsent(
        member.id,
        () => TextEditingController(),
      );
      controller.text = percent.toString();
    }
  }

  void _onPercentageChanged(String id) {
    if (_controllers[id]!.text.trim().isEmpty) {
      _editedPercentageIds.remove(id);
    } else {
      _editedPercentageIds.add(id);
    }
    final remaining = widget.members
        .where((member) => !_editedPercentageIds.contains(member.id))
        .toList();
    if (remaining.length == 1 && remaining.single.id != id) {
      final remainingId = remaining.single.id;
      var total = 0.0;
      var valid = true;
      for (final member in widget.members) {
        if (member.id == remainingId) continue;
        final value = double.tryParse(_controllers[member.id]!.text.trim());
        if (value == null || !value.isFinite || value < 0 || value > 100) {
          valid = false;
          break;
        }
        total += value;
      }
      if (valid && total <= 100) {
        // Suppress floating-point tails such as 33.340000000000003 without
        // changing any manually entered share or overwriting the active field.
        _controllers[remainingId]!.text = (100 - total)
            .toStringAsFixed(10)
            .replaceFirst(RegExp(r'\.?0+$'), '');
      }
    }
    _emitPercentages();
  }

  void _emitPercentages() {
    widget.onChanged(
      ExpenseSplit(
        splitWith: widget.members.map((member) => member.id).toList(),
        percentages: {
          for (final member in widget.members)
            member.id:
                double.tryParse(_controllers[member.id]!.text.trim()) ??
                double.nan,
        },
      ),
    );
  }

  void _choose(_SplitChoice choice) {
    if (choice == _choice) return;
    setState(() => _choice = choice);
    switch (choice) {
      case _SplitChoice.justMe:
        widget.onChanged(ExpenseSplit(splitWith: [widget.currentUserId]));
      case _SplitChoice.evenly:
        widget.onChanged(
          ExpenseSplit(
            splitWith: widget.members.map((member) => member.id).toList(),
          ),
        );
      case _SplitChoice.custom:
        _seedPercentages();
        _emitPercentages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.value.validationError;
    final percentages = widget.value.percentages;
    final total = percentages?.values
        .where((value) => value.isFinite)
        .fold<double>(0, (sum, value) => sum + value);
    final validAmount =
        widget.amount.isFinite &&
        widget.amount >= 0 &&
        (widget.amount * 100).isFinite;
    final amounts = error == null && validAmount
        ? widget.value.amountsFor(widget.amount)
        : const <String, double>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split this expense', style: AppTextStyles.body),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final option in const {
              _SplitChoice.justMe: 'All me',
              _SplitChoice.evenly: 'Divide evenly',
              _SplitChoice.custom: 'Custom %',
            }.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: _choice == option.key,
                onSelected: widget.enabled ? (_) => _choose(option.key) : null,
              ),
          ],
        ),
        if (_choice == _SplitChoice.evenly) ...[
          const SizedBox(height: 10),
          Text('Choose who shares this expense.', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final member in widget.members)
                FilterChip(
                  label: Text(member.username),
                  selected: widget.value.splitWith.contains(member.id),
                  onSelected: widget.enabled
                      ? (selected) {
                          final ids = widget.value.splitWith.toSet();
                          selected ? ids.add(member.id) : ids.remove(member.id);
                          widget.onChanged(
                            ExpenseSplit(
                              splitWith: [
                                for (final member in widget.members)
                                  if (ids.contains(member.id)) member.id,
                              ],
                            ),
                          );
                        }
                      : null,
                ),
            ],
          ),
        ],
        if (_choice == _SplitChoice.custom) ...[
          const SizedBox(height: 10),
          Text(
            'The last unedited share fills automatically to total 100%. '
            'Use 0% to leave someone out.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          for (final member in widget.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.username, style: AppTextStyles.body),
                        Text(
                          amounts.containsKey(member.id)
                              ? '\$${amounts[member.id]!.toStringAsFixed(2)}'
                              : '—',
                          key: ValueKey('split_amount_${member.id}'),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 106,
                    child: TextField(
                      key: ValueKey('split_percentage_${member.id}'),
                      controller: _controllers[member.id],
                      enabled: widget.enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: AppTextStyles.body,
                      decoration: AppDecorations.inputDecoration(label: 'Share')
                          .copyWith(
                            suffixText: '%',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                      onChanged: (_) => _onPercentageChanged(member.id),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Assigned: ${total?.toStringAsFixed(2) ?? '0.00'}% / 100%',
            style: AppTextStyles.body.copyWith(
              color: error == null ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
