import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/expense_split.dart';
import '../models/group.dart';
import '../services/expense_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/expense_split_editor.dart';
import '../widgets/gradient_app_bar.dart';

/// Three-panel "Cost Splitter" layout: itemized expenses, a total + add-expense
/// form, and each member's allocated costs. Expenses default to personal, with
/// equal and custom percentage splits. Panels stack below [_wideBreakpoint].
const double _wideBreakpoint = 760;

class TripExpensesPage extends StatefulWidget {
  const TripExpensesPage({
    super.key,
    required this.group,
    ExpenseService? service,
  }) : _service = service;

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
  late ExpenseSplit _split = ExpenseSplit(splitWith: [_service.currentUserId]);
  late final _expenses = _service.expensesStream(widget.group.id);

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (_busy) return;
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (name.isEmpty ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        !(amount * 100).isFinite ||
        (amount * 100).round() == 0) {
      setState(() => _formError = 'Enter a name and a valid cost.');
      return;
    }
    if (_split.validationError != null) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await _service.addExpense(
        widget.group.id,
        name: name,
        amount: amount,
        splitWith: _split.splitWith,
        splitPercentages: _split.percentages,
      );
      if (!mounted) return;
      _nameController.clear();
      _amountController.clear();
    } catch (e) {
      if (mounted) {
        setState(() => _formError = 'Couldn\'t save the expense: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t delete the expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _service.currentUserId;
    final isAdmin =
        widget.group.memberById(currentUserId)?.role == GroupRole.admin;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GradientAppBar(title: 'Cost Splitter'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: StreamBuilder<List<Expense>>(
            stream: _expenses,
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? const <Expense>[];
              final total = expenses.fold<double>(
                0,
                (sum, e) => sum + e.amount,
              );
              final members = widget.group.members;

              // Use the same cent allocation as the percentage preview.
              final totalsByMember = <String, double>{
                for (final m in members) m.id: 0,
              };
              for (final expense in expenses) {
                for (final share
                    in expense.split.amountsFor(expense.amount).entries) {
                  totalsByMember[share.key] =
                      (totalsByMember[share.key] ?? 0) + share.value;
                }
              }

              final breakdown = _ItemizedBreakdown(
                expenses: expenses,
                currentUserId: currentUserId,
                isAdmin: isAdmin,
                onDelete: _deleteExpense,
                members: members,
              );
              final addForm = _AddExpenseForm(
                total: total,
                nameController: _nameController,
                amountController: _amountController,
                error: _formError,
                busy: _busy,
                onAdd: _addExpense,
                split: _split,
                members: members,
                currentUserId: currentUserId,
                onSplitChanged: (split) => setState(() => _split = split),
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
    required this.members,
  });

  final List<Expense> expenses;
  final String currentUserId;
  final bool isAdmin;
  final ValueChanged<Expense> onDelete;
  final List<GroupMember> members;

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
            Text(
              'No expenses yet.',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            )
          else
            ...expenses.map((expense) {
              final canDelete = isAdmin || expense.addedBy == currentUserId;
              final percentages = expense.split.percentagesByMember;
              final amounts = expense.split.amountsFor(expense.amount);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final share in amounts.entries)
                      if ((percentages[share.key] ?? 0) > 0)
                        Text(
                          '${_memberName(share.key)} · ${percentages[share.key]!.toStringAsFixed(2)}% · \$${share.value.toStringAsFixed(2)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
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

  String _memberName(String id) {
    for (final member in members) {
      if (member.id == id) return member.username;
    }
    return 'Former member';
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
    required this.split,
    required this.members,
    required this.currentUserId,
    required this.onSplitChanged,
  });

  final double total;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final String? error;
  final bool busy;
  final VoidCallback onAdd;
  final ExpenseSplit split;
  final List<GroupMember> members;
  final String currentUserId;
  final ValueChanged<ExpenseSplit> onSplitChanged;

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
            enabled: !busy,
            style: AppTextStyles.body,
            decoration: AppDecorations.inputDecoration(label: 'Expense Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            enabled: !busy,
            style: AppTextStyles.body,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: AppDecorations.inputDecoration(label: 'Cost'),
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: amountController,
            builder: (context, value, _) => ExpenseSplitEditor(
              members: members,
              currentUserId: currentUserId,
              value: split,
              amount: double.tryParse(value.text.trim()) ?? 0,
              enabled: !busy,
              onChanged: onSplitChanged,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 18),
          GradientButton(
            onPressed: busy || split.validationError != null ? null : onAdd,
            label: 'Add',
            isLoading: busy,
          ),
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
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
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
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.accentEnd,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: AppTextStyles.caption,
                      ),
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
