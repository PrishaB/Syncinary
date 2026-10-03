import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/gradient_app_bar.dart';
import 'itinerary_builder.dart';

/// Itinerary landing page ("Schedule Builder"): an AI advisor panel, a summary
/// of the group's preferences, and the day-by-day schedule. The schedule is
/// live (Firestore via [ScheduleService]); the advisor and preferences panels
/// are placeholders until preference collection and the Gemini integration
/// exist. Panels stack below [_wideBreakpoint], schedule first, so the part
/// that does something stays on top at phone width.
const double _wideBreakpoint = 760;

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Monday, May 3rd"
String formatScheduleDay(DateTime date) {
  final d = date.day;
  final suffix = (d >= 11 && d <= 13)
      ? 'th'
      : switch (d % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  return '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} $d$suffix';
}

/// Entry point for "Plan Itinerary". The first time a user plans a given
/// trip, this shows the original origin → destination → dates flow
/// ([itinerary_builder]); backing out of it turns this same screen into the
/// [ScheduleBuilderPage], which is where "Plan Itinerary" goes from then on.
class PlanItineraryPage extends StatefulWidget {
  const PlanItineraryPage({super.key, required this.group, ScheduleService? service})
      : _service = service;

  final Group group;
  final ScheduleService? _service;

  @override
  State<PlanItineraryPage> createState() => _PlanItineraryPageState();
}

class _PlanItineraryPageState extends State<PlanItineraryPage> {
  late final ScheduleService _service = widget._service ?? ScheduleService();

  /// Null while checking Firestore.
  bool? _started;

  @override
  void initState() {
    super.initState();
    _service.hasStartedItinerary(widget.group.id).then(
          (started) => started,
          onError: (_) => false, // Can't tell — fall back to the setup flow.
        ).then((started) {
      if (mounted) setState(() => _started = started);
    });
  }

  Future<void> _finishSetup() async {
    setState(() => _started = true);
    try {
      await _service.markItineraryStarted(widget.group.id);
    } catch (_) {
      // Non-fatal: they'll just see the setup flow again next time.
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_started) {
      null => const Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      true => ScheduleBuilderPage(group: widget.group, service: _service),
      false => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _finishSetup();
          },
          child: const itinerary_builder(),
        ),
    };
  }
}

class ScheduleBuilderPage extends StatefulWidget {
  const ScheduleBuilderPage({super.key, required this.group, ScheduleService? service})
      : _service = service;

  final Group group;
  final ScheduleService? _service;

  @override
  State<ScheduleBuilderPage> createState() => _ScheduleBuilderPageState();
}

class _ScheduleBuilderPageState extends State<ScheduleBuilderPage> {
  late final ScheduleService _service = widget._service ?? ScheduleService();

  String get _groupId => widget.group.id;

  void _showError(String action, Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Couldn\'t $action: $e')));
  }

  Future<void> _addDay(List<ScheduleDay> existing) async {
    final now = DateTime.now();
    final initial = existing.isNotEmpty
        ? existing.last.date.add(const Duration(days: 1))
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    try {
      await _service.addDay(_groupId, picked);
    } catch (e) {
      _showError('add the day', e);
    }
  }

  Future<void> _deleteDay(ScheduleDay day) async {
    final confirmed = await showConfirmationDialog(
      context,
      message: 'Remove ${formatScheduleDay(day.date)} and everything planned on it?',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    try {
      await _service.deleteDay(_groupId, day.key);
    } catch (e) {
      _showError('remove the day', e);
    }
  }

  void _addFlight(ScheduleDay day) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const itinerary_builder()),
    );
  }

  Future<void> _addItem(ScheduleDay day, ScheduleItemType type) async {
    final result = await _showItemDialog(context, type: type);
    if (result == null) return;
    try {
      await _service.addItem(_groupId,
          dayKey: day.key, type: type, title: result.title, details: result.details);
    } catch (e) {
      _showError('add the ${scheduleItemTypeToString(type)}', e);
    }
  }

  Future<void> _editItem(ScheduleItem item) async {
    final result = await _showItemDialog(context,
        type: item.type, initialTitle: item.title, initialDetails: item.details);
    if (result == null) return;
    try {
      await _service.updateItem(_groupId, item.id,
          title: result.title, details: result.details);
    } catch (e) {
      _showError('save the change', e);
    }
  }

  Future<void> _deleteItem(ScheduleItem item) async {
    final confirmed = await showConfirmationDialog(
      context,
      message: 'Remove "${item.title}" from the schedule?',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    try {
      await _service.deleteItem(_groupId, item.id);
    } catch (e) {
      _showError('remove the item', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GradientAppBar(title: 'Schedule Builder'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: StreamBuilder<List<ScheduleDay>>(
            stream: _service.daysStream(_groupId),
            builder: (context, daysSnapshot) {
              return StreamBuilder<List<ScheduleItem>>(
                stream: _service.itemsStream(_groupId),
                builder: (context, itemsSnapshot) {
                  final days = daysSnapshot.data ?? const <ScheduleDay>[];
                  final items = itemsSnapshot.data ?? const <ScheduleItem>[];

                  const advisor = _AdvisorPanel();
                  const preferences = _PreferencesPanel();
                  final schedule = _SchedulePanel(
                    days: days,
                    items: items,
                    onAddDay: () => _addDay(days),
                    onDeleteDay: _deleteDay,
                    onAddFlight: _addFlight,
                    onAddItem: _addItem,
                    onEditItem: _editItem,
                    onDeleteItem: _deleteItem,
                  );
                  final mapView = Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Map view — coming soon')),
                      ),
                      icon: const Icon(Icons.map_outlined, color: AppColors.accentEnd),
                      label: Text('Map View',
                          style: AppTextStyles.body.copyWith(color: AppColors.accentEnd)),
                    ),
                  );

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      const padding = EdgeInsets.fromLTRB(24, 88, 24, 32);
                      if (constraints.maxWidth >= _wideBreakpoint) {
                        return SingleChildScrollView(
                          padding: padding,
                          child: Column(
                            children: [
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Expanded(child: advisor),
                                    const SizedBox(width: 16),
                                    const Expanded(child: preferences),
                                    const SizedBox(width: 16),
                                    Expanded(child: schedule),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              mapView,
                            ],
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        padding: padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            schedule,
                            const SizedBox(height: 20),
                            preferences,
                            const SizedBox(height: 20),
                            advisor,
                            const SizedBox(height: 12),
                            mapView,
                          ],
                        ),
                      );
                    },
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

// ─────────────────────────────────────────────────────────
// Panels
// ─────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// A rounded inner card, used for preference sections and schedule entries.
BoxDecoration _innerCard() => BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    );

class _AdvisorPanel extends StatelessWidget {
  const _AdvisorPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'AI Advisor',
      subtitle: 'Powered by Gemini',
      children: [
        Icon(Icons.auto_awesome_rounded,
            size: 40, color: AppColors.textMuted.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(
          'Coming soon — suggested flights, hotels, and activities based on '
          'your group\'s preferences will appear here.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel();

  static const _sections = [
    (Icons.account_balance_wallet_outlined, 'Budget'),
    (Icons.hotel_outlined, 'Lodging'),
    (Icons.flight_outlined, 'Flight Details'),
    (Icons.place_outlined, 'Location/Activities'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Group Preferences',
      children: [
        for (final (icon, label) in _sections) ...[
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accentEnd),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _innerCard(),
            child: Text('No preferences shared yet.', style: AppTextStyles.caption),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
    required this.days,
    required this.items,
    required this.onAddDay,
    required this.onDeleteDay,
    required this.onAddFlight,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final List<ScheduleDay> days;
  final List<ScheduleItem> items;
  final VoidCallback onAddDay;
  final ValueChanged<ScheduleDay> onDeleteDay;
  final ValueChanged<ScheduleDay> onAddFlight;
  final void Function(ScheduleDay day, ScheduleItemType type) onAddItem;
  final ValueChanged<ScheduleItem> onEditItem;
  final ValueChanged<ScheduleItem> onDeleteItem;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Schedule',
      children: [
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('No days planned yet. Add a day to start the schedule.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        for (final day in days) ...[
          Row(
            children: [
              Expanded(
                child: Text(formatScheduleDay(day.date),
                    style: AppTextStyles.title.copyWith(fontSize: 18)),
              ),
              IconButton(
                tooltip: 'Remove day',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => onDeleteDay(day),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items.where((i) => i.day == day.key))
            _ScheduleItemCard(
              item: item,
              onEdit: () => onEditItem(item),
              onDelete: () => onDeleteItem(item),
            ),
          _AddTile(label: 'Add Flight', onTap: () => onAddFlight(day)),
          _AddTile(label: 'Add Hotel', onTap: () => onAddItem(day, ScheduleItemType.hotel)),
          _AddTile(
              label: 'Add Activity', onTap: () => onAddItem(day, ScheduleItemType.activity)),
          const SizedBox(height: 16),
        ],
        GradientButton(onPressed: onAddDay, label: 'Add Day'),
      ],
    );
  }
}

class _ScheduleItemCard extends StatelessWidget {
  const _ScheduleItemCard({required this.item, required this.onEdit, required this.onDelete});

  final ScheduleItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = item.type == ScheduleItemType.hotel
        ? Icons.hotel_rounded
        : Icons.local_activity_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: _innerCard(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentEnd, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTextStyles.body),
                if (item.details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.details, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: _innerCard(),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppTextStyles.body)),
                const Icon(Icons.add_rounded, color: AppColors.accentEnd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Add / edit item dialog
// ─────────────────────────────────────────────────────────

Future<({String title, String details})?> _showItemDialog(
  BuildContext context, {
  required ScheduleItemType type,
  String initialTitle = '',
  String initialDetails = '',
}) {
  final isHotel = type == ScheduleItemType.hotel;
  final isEdit = initialTitle.isNotEmpty;
  final titleController = TextEditingController(text: initialTitle);
  final detailsController = TextEditingController(text: initialDetails);

  return showDialog<({String title, String details})>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppDecorations.glassCard(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${isEdit ? 'Edit' : 'Add'} ${isHotel ? 'Hotel' : 'Activity'}',
                style: AppTextStyles.title),
            const SizedBox(height: 18),
            TextField(
              controller: titleController,
              autofocus: true,
              style: AppTextStyles.body,
              decoration: AppDecorations.inputDecoration(
                label: isHotel ? 'Hotel name' : 'Activity',
                prefixIcon: isHotel ? Icons.hotel_outlined : Icons.local_activity_outlined,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              style: AppTextStyles.body,
              decoration: AppDecorations.inputDecoration(
                label: isHotel ? 'Details (e.g. 1 bed)' : 'Details (e.g. time, tickets)',
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('Cancel',
                        style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      Navigator.of(dialogContext)
                          .pop((title: title, details: detailsController.text.trim()));
                    },
                    label: 'Save',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
