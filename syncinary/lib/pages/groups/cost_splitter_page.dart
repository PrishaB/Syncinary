import 'package:flutter/material.dart';

import '../../models/cost_split.dart';
import '../../models/group.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_app_bar.dart';

class CostSplitterPage extends StatefulWidget {
  const CostSplitterPage({super.key, required this.group});

  final Group group;

  @override
  State<CostSplitterPage> createState() => _CostSplitterPageState();
}

class _CostSplitterPageState extends State<CostSplitterPage> {
  final List<_Cost> _costs = [];
  late final _members = List<GroupMember>.of(widget.group.members);
  late List<int> _shares = allocateUnits(100, List.filled(_members.length, 1));

  int get _total => _costs.fold(0, (sum, cost) => sum + cost.cents);

  Future<void> _addCost() async {
    final cost = await showDialog<_Cost>(
      context: context,
      builder: (_) => const _AddCostDialog(),
    );
    if (cost != null && mounted) setState(() => _costs.add(cost));
  }

  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: AppDecorations.glassCard(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _costPanel() => _panel([
    Text('Costs', style: AppTextStyles.title),
    const SizedBox(height: 16),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: _addCost,
        icon: const Icon(Icons.add),
        label: const Text('Add cost'),
      ),
    ),
    const SizedBox(height: 16),
    if (_costs.isEmpty)
      const Text('No costs yet. Add a cost to start splitting.'),
    for (final cost in _costs)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(cost.name)),
            const SizedBox(width: 8),
            Text(_money(cost.cents)),
            IconButton(
              tooltip: 'Remove ${cost.name}',
              onPressed: () => setState(() => _costs.remove(cost)),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    const Divider(height: 32),
    Text('Total: ${_money(_total)}', style: AppTextStyles.title),
  ]);

  Widget _memberPanel() {
    final amounts = allocateUnits(_total, _shares);
    return _panel([
      Row(
        children: [
          Expanded(child: Text('Members', style: AppTextStyles.title)),
          if (_members.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _shares = allocateUnits(100, List.filled(_members.length, 1));
              }),
              child: const Text('Split equally'),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_members.isEmpty)
        const Text('No members to split costs with.')
      else ...[
        for (var i = 0; i < _members.length; i++) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(_members[i].username)),
              Text('${_shares[i]}%'),
            ],
          ),
          Slider(
            key: ValueKey('share-${_members[i].id}'),
            value: _shares[i].toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_shares[i]}%',
            semanticFormatterCallback: (value) =>
                '${_members[i].username}: ${value.round()} percent',
            onChanged: _members.length == 1
                ? null
                : (value) => setState(() {
                    _shares = adjustCostShares(_shares, i, value.round());
                  }),
          ),
          Text('Owes ${_money(amounts[i])}', style: AppTextStyles.subtitle),
          const Divider(height: 24),
        ],
        if (_members.length == 1)
          const Text('The only member receives 100% of the costs.'),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const GradientAppBar(title: 'Cost Splitter'),
    body: Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final costs = _costPanel();
            final members = _memberPanel();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.group.name, style: AppTextStyles.headline),
                  const SizedBox(height: 8),
                  const Text(
                    'Costs and shares are kept only while this page is open.',
                  ),
                  const SizedBox(height: 24),
                  if (constraints.maxWidth >= 700)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: costs),
                        const SizedBox(width: 24),
                        Expanded(child: members),
                      ],
                    )
                  else ...[
                    costs,
                    const SizedBox(height: 24),
                    members,
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

class _Cost {
  const _Cost(this.name, this.cents);
  final String name;
  final int cents;
}

class _AddCostDialog extends StatefulWidget {
  const _AddCostDialog();

  @override
  State<_AddCostDialog> createState() => _AddCostDialogState();
}

class _AddCostDialogState extends State<_AddCostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();

  int? _parseCents(String text) {
    if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(text.trim())) return null;
    final parts = text.trim().split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(
        context,
        _Cost(_name.text.trim(), _parseCents(_amount.text)!),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add cost'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Cost name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a cost name.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Dollar amount',
                prefixText: '\$ ',
                hintText: '0.00',
              ),
              validator: (value) {
                final cents = _parseCents(value ?? '');
                return cents == null || cents <= 0
                    ? 'Enter a positive amount (up to 2 decimal places).'
                    : null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Add')),
    ],
  );
}
