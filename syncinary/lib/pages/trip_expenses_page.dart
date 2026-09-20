import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../services/expense_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/gradient_app_bar.dart';

/// Three-panel "Cost Splitter" layout: itemized expenses, a total + add-expense
/// form, and a per-person breakdown of what each member has added — an expense
/// is attributed entirely to whoever added it, not split across the group by
/// default. Panels stack vertically below [_wideBreakpoint] so the page still
/// works at phone width.
const double _wideBreakpoint = 760;

enum _SplitChoice { justMe, selected }

class TripExpensesPage extends StatefulWidget {
  const TripExpensesPage({super.key, required this.group, ExpenseService? service})
      : _service = service;

  final Group group;
  final ExpenseService? _service;

  @override
  State<TripExpensesPage> createState() => _TripExpensesPageState();
}

class _TripExpensesPageState extends State<TripExpensesPage> {
  late final ExpenseService _service = widget._service ?? ExpenseService();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _formError;
  bool _busy = false;
  _SplitChoice _splitChoice = _SplitChoice.justMe;
  List<GroupMember> _splitMembers = const [];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) {
      setState(() => _formError = 'Enter a name and a valid cost.');
      return;
    }
    final splitWith = _splitChoice == _SplitChoice.justMe
        ? [_service.currentUserId]
        : _splitMembers.map((m) => m.id).toList();
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await _service.addExpense(widget.group.id, name: name, amount: amount, splitWith: splitWith);
      _nameController.clear();
      _amountController.clear();
    } catch (e) {
      if (mounted) setState(() => _formError = 'Couldn\'t save the expense: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSplitChoiceChanged(_SplitChoice? choice) async {
    if (choice == _SplitChoice.justMe) {
      setState(() {
        _splitChoice = _SplitChoice.justMe;
        _splitMembers = const [];
      });
      return;
    }
    await _editSplitMembers();
  }

  Future<void> _editSplitMembers() async {
    final members = widget.group.members;
    final picked = await _showSplitMembersDialog(
      context,
      members: members,
      initiallySelected: _splitMembers.isEmpty ? members : _splitMembers,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _splitChoice = _SplitChoice.selected;
      _splitMembers = picked;
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showConfirmationDialog(
      context,
      message: 'Delete "${expense.name}"?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await _service.deleteExpense(widget.group.id, expense.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Couldn\'t delete the expense: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _service.currentUserId;
    final isAdmin = widget.group.memberById(currentUserId)?.role == GroupRole.admin;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GradientAppBar(title: 'Cost Splitter'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: StreamBuilder<List<Expense>>(
            stream: _service.expensesStream(widget.group.id),
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? const <Expense>[];
              final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
              final members = widget.group.members;

              // Each expense is split evenly only across its own splitWith list
              // (just the adder by default) — not across the whole group.
              final totalsByMember = <String, double>{for (final m in members) m.id: 0};
              for (final expense in expenses) {
                final perPerson = expense.amount / expense.splitWith.length;
                for (final uid in expense.splitWith) {
                  totalsByMember[uid] = (totalsByMember[uid] ?? 0) + perPerson;
                }
              }

              final breakdown = _ItemizedBreakdown(
                expenses: expenses,
                currentUserId: currentUserId,
                isAdmin: isAdmin,
                onDelete: _deleteExpense,
              );
              final addForm = _AddExpenseForm(
                total: total,
                nameController: _nameController,
                amountController: _amountController,
                error: _formError,
                busy: _busy,
                onAdd: _addExpense,
                splitChoice: _splitChoice,
                splitMembers: _splitMembers,
                onSplitChoiceChanged: _onSplitChoiceChanged,
                onEditSplitMembers: _editSplitMembers,
              );
              final splitPanel = _PerPersonPanel(
                members: members,
                total: total,
                totalsByMember: totalsByMember,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final padding = const EdgeInsets.fromLTRB(24, 88, 24, 32);
                  if (constraints.maxWidth >= _wideBreakpoint) {
                    return SingleChildScrollView(
                      padding: padding,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: breakdown),
                            const SizedBox(width: 16),
                            Expanded(child: addForm),
                            const SizedBox(width: 16),
                            Expanded(child: splitPanel),
                          ],
                        ),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        breakdown,
                        const SizedBox(height: 20),
                        addForm,
                        const SizedBox(height: 20),
                        splitPanel,
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ItemizedBreakdown extends StatelessWidget {
  const _ItemizedBreakdown({
    required this.expenses,
    required this.currentUserId,
    required this.isAdmin,
    required this.onDelete,
  });

  final List<Expense> expenses;
  final String currentUserId;
  final bool isAdmin;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Itemized Breakdown', style: AppTextStyles.title),
          const SizedBox(height: 14),
          if (expenses.isEmpty)
            Text('No expenses yet.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted))
          else
            ...expenses.map((expense) {
              final canDelete = isAdmin || expense.addedBy == currentUserId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${expense.name}: \$${expense.amount.toStringAsFixed(2)}',
                        style: AppTextStyles.body,
                      ),
                    ),
                    if (canDelete)
                      InkWell(
                        onTap: () => onDelete(expense),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AddExpenseForm extends StatelessWidget {
  const _AddExpenseForm({
    required this.total,
    required this.nameController,
    required this.amountController,
    required this.error,
    required this.busy,
    required this.onAdd,
    required this.splitChoice,
    required this.splitMembers,
    required this.onSplitChoiceChanged,
    required this.onEditSplitMembers,
  });

  final double total;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final String? error;
  final bool busy;
  final VoidCallback onAdd;
  final _SplitChoice splitChoice;
  final List<GroupMember> splitMembers;
  final ValueChanged<_SplitChoice?> onSplitChoiceChanged;
  final VoidCallback onEditSplitMembers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glassCard(),
      child: Column(
        children: [
          Text('Total', style: AppTextStyles.subtitle),
          const SizedBox(height: 4),
          Text('\$${total.toStringAsFixed(2)}', style: AppTextStyles.headline),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Add a custom expense', style: AppTextStyles.body),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            style: AppTextStyles.body,
            decoration: AppDecorations.inputDecoration(label: 'Expense Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            style: AppTextStyles.body,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: AppDecorations.inputDecoration(label: 'Cost'),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 18),
          GradientButton(onPressed: busy ? null : onAdd, label: 'Add', isLoading: busy),
          const SizedBox(height: 18),
          DropdownButtonFormField<_SplitChoice>(
            key: ValueKey(splitChoice),
            initialValue: splitChoice,
            isExpanded: true,
            dropdownColor: AppColors.surfaceLight,
            style: AppTextStyles.body,
            decoration: AppDecorations.inputDecoration(label: 'Split cost'),
            items: const [
              DropdownMenuItem(
                value: _SplitChoice.justMe,
                child: Text('Just Me', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: _SplitChoice.selected,
                child: Text('Split Evenly With...', overflow: TextOverflow.ellipsis),
              ),
            ],
            onChanged: onSplitChoiceChanged,
          ),
          if (splitChoice == _SplitChoice.selected) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onEditSplitMembers,
                child: Text(
                  'Splitting with: ${splitMembers.map((m) => m.username).join(', ')}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.accentEnd),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerPersonPanel extends StatelessWidget {
  const _PerPersonPanel({
    required this.members,
    required this.total,
    required this.totalsByMember,
  });

  final List<GroupMember> members;
  final double total;
  final Map<String, double> totalsByMember;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('By Person', style: AppTextStyles.body),
            ),
          ),
          const SizedBox(height: 18),
          ...members.map((member) {
            final memberTotal = totalsByMember[member.id] ?? 0;
            final percent = total > 0 ? memberTotal / total * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.surfaceLight,
                        child: Icon(Icons.person, size: 16, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${member.username}: \$${memberTotal.toStringAsFixed(2)}',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceLight,
                            valueColor: const AlwaysStoppedAnimation(AppColors.accentEnd),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${percent.toStringAsFixed(0)}%', style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Multi-select dialog for picking which group members share an expense
/// evenly. Returns the chosen members, or null if the user cancelled.
Future<List<GroupMember>?> _showSplitMembersDialog(
  BuildContext context, {
  required List<GroupMember> members,
  required List<GroupMember> initiallySelected,
}) {
  return showDialog<List<GroupMember>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) =>
        _SplitMembersDialog(members: members, initiallySelected: initiallySelected),
  );
}

class _SplitMembersDialog extends StatefulWidget {
  const _SplitMembersDialog({required this.members, required this.initiallySelected});

  final List<GroupMember> members;
  final List<GroupMember> initiallySelected;

  @override
  State<_SplitMembersDialog> createState() => _SplitMembersDialogState();
}

class _SplitMembersDialogState extends State<_SplitMembersDialog> {
  late final Set<String> _selectedIds =
      widget.initiallySelected.map((m) => m.id).toSet();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentStart.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Split Evenly With...',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(color: Colors.white)),
            const SizedBox(height: 18),
            ...widget.members.map((member) {
              final isSelected = _selectedIds.contains(member.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedIds.remove(member.id);
                      } else {
                        _selectedIds.add(member.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            child: Text(
                              member.username.isNotEmpty
                                  ? member.username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(member.username,
                                style: AppTextStyles.body.copyWith(color: Colors.white)),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.accentStart,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          widget.members.where((m) => _selectedIds.contains(m.id)).toList(),
                        ),
                child: Text('Confirm Selection',
                    style: AppTextStyles.button.copyWith(color: AppColors.accentStart)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTextStyles.button.copyWith(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
