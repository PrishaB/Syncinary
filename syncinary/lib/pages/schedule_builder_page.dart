import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/gradient_app_bar.dart';
import 'groups/group_preferences_page.dart';
import 'itinerary_builder.dart';

/// Itinerary landing page ("Schedule Builder"): an AI advisor panel, the plan
/// for one selected day, and an "Add to Trip" panel with a button per item
/// type (activity, flight, hotel). Adding asks for the date, so days are
/// created as items land on them, and items are only listed in the Day Plan
/// or, while pending, in Suggestions.
/// The schedule is shared by the whole group and live (Firestore via
/// [ScheduleService]), and every entry is labelled with the member who added
/// it. Members suggest; the admin decides: a member's item goes to the
/// Suggestions panel until the admin approves it into the Day Plan or rejects
/// it, and only the admin edits or removes what's on the itinerary. The
/// Firestore rules enforce the same split. The advisor panel is a placeholder until the Gemini integration
/// exists. Panels stack below [_wideBreakpoint], add panel first, so the part
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

/// Where "Plan Itinerary" on a trip goes.
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

  /// The day shown in the Day Plan panel. Null, or a day that has since been
  /// removed, falls back to the first day of the trip.
  String? _selectedDayKey;

  ScheduleDay? _selectedDay(List<ScheduleDay> days) {
    for (final day in days) {
      if (day.key == _selectedDayKey) return day;
    }
    return days.isEmpty ? null : days.first;
  }

  void _selectDay(ScheduleDay day) => setState(() => _selectedDayKey = day.key);

  /// Only the admin adds straight to the itinerary, approves suggestions, and
  /// edits or removes itinerary items.
  bool get _isAdmin =>
      widget.group.memberById(_service.currentUserId)?.role == GroupRole.admin;

  /// "Added by …" / "Suggested by …" for [item], or null for items saved
  /// before `addedBy` was read.
  void _openGroupPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPreferencesPage(
          groupId: _groupId,
          groupName: widget.group.name,
          service: _service.groupPreferencesService,
        ),
      ),
    );
  }

  /// "Added by …" for [item], or null for items saved before `addedBy` was read.
  String? _attribution(ScheduleItem item) {
    if (item.addedBy.isEmpty) return null;
    final verb = item.isSuggestion ? 'Suggested' : 'Added';
    if (item.addedBy == _service.currentUserId) return '$verb by you';
    final name = widget.group.memberById(item.addedBy)?.username ?? 'a former member';
    return '$verb by $name';
  }

  void _showError(String action, Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Couldn\'t $action: $e')));
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

  /// The original origin → destination → dates search, reachable from the
  /// Add Flight / Add Hotel dialogs for anyone who'd rather look one up than
  /// type it in. Opens with the Flights/Hotels toggle already on [searchType].
  void _openSearch(SearchType searchType) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => itinerary_builder(initialSearchType: searchType)),
    );
  }

  /// Adds an item on the date picked in the dialog (defaulting to the day open
  /// in the Day Plan), then shows that day. The admin's item goes straight
  /// onto the itinerary; a member's becomes a suggestion.
  Future<void> _addItem(ScheduleItemType type, ScheduleDay? selectedDay) async {
    final suggest = !_isAdmin;
    final result = await _showItemDialog(context,
        type: type,
        suggest: suggest,
        initialDate: selectedDay?.date ?? DateTime.now(),
        search: switch (type) {
          ScheduleItemType.flight =>
            (label: 'Search flights', onTap: () => _openSearch(SearchType.flights)),
          ScheduleItemType.hotel =>
            (label: 'Search hotels', onTap: () => _openSearch(SearchType.hotels)),
          ScheduleItemType.activity => null,
        });
    if (result == null) return;
    try {
      await _service.addItem(_groupId,
          date: result.date,
          type: type,
          title: result.title,
          details: result.details,
          status: suggest ? ScheduleItemStatus.suggested : ScheduleItemStatus.approved);
      if (!mounted) return;
      setState(() => _selectedDayKey = scheduleDayKey(result.date));
      if (suggest) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Suggestion sent — the trip admin will approve or reject it.')));
      }
    } catch (e) {
      _showError('${suggest ? 'suggest' : 'add'} the ${_typeInfo(type).noun}', e);
    }
  }

  Future<void> _approveItem(ScheduleItem item) async {
    try {
      await _service.approveItem(_groupId, item.id);
      if (mounted) setState(() => _selectedDayKey = item.day);
    } catch (e) {
      _showError('approve the suggestion', e);
    }
  }

  /// Rejecting (admin) and withdrawing (the member who suggested it) both
  /// delete the suggestion.
  Future<void> _discardSuggestion(ScheduleItem item, {required bool reject}) async {
    final confirmed = await showConfirmationDialog(
      context,
      message: reject
          ? 'Reject the suggestion "${item.title}"?'
          : 'Withdraw your suggestion "${item.title}"?',
      confirmLabel: reject ? 'Reject' : 'Withdraw',
    );
    if (!confirmed) return;
    try {
      await _service.deleteItem(_groupId, item.id);
    } catch (e) {
      _showError('${reject ? 'reject' : 'withdraw'} the suggestion', e);
    }
  }

  Future<void> _editItem(ScheduleItem item, DateTime currentDate) async {
    final result = await _showItemDialog(context,
        type: item.type,
        initialDate: currentDate,
        initialTitle: item.title,
        initialDetails: item.details);
    if (result == null) return;
    try {
      await _service.updateItem(_groupId, item.id,
          date: result.date, title: result.title, details: result.details);
      if (mounted) setState(() => _selectedDayKey = scheduleDayKey(result.date));
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

                  final selectedDay = _selectedDay(days);
                  final isAdmin = _isAdmin;
                  final itinerary = items.where((i) => !i.isSuggestion).toList();
                  final suggestions = items.where((i) => i.isSuggestion).toList();

                  const advisor = _AdvisorPanel();
                  final dayPlan = _DayPlanPanel(
                    days: days,
                    selectedDay: selectedDay,
                    items: itinerary,
                    attribution: _attribution,
                    onSelectDay: _selectDay,
                    // Removing a day removes its itinerary items, so admin only.
                    onDeleteDay: isAdmin ? _deleteDay : null,
                    onEditItem: isAdmin ? (item) => _editItem(item, selectedDay!.date) : null,
                    onDeleteItem: isAdmin ? _deleteItem : null,
                  );
                  final addPanel = _AddToTripPanel(
                    suggest: !isAdmin,
                    onAdd: (type) => _addItem(type, selectedDay),
                  );
                  final suggestionsPanel = _SuggestionsPanel(
                    suggestions: suggestions,
                    attribution: _attribution,
                    onApprove: isAdmin ? _approveItem : null,
                    onReject: isAdmin
                        ? (item) => _discardSuggestion(item, reject: true)
                        : null,
                    // A member can take back their own pending suggestion.
                    currentUserId: _service.currentUserId,
                    onWithdraw: isAdmin
                        ? null
                        : (item) => _discardSuggestion(item, reject: false),
                  final preferencesLink = Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _openGroupPreferences,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('Group Preferences'),
                    ),
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
                              preferencesLink,
                              const SizedBox(height: 16),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Expanded(child: advisor),
                                    const SizedBox(width: 16),
                                    Expanded(child: dayPlan),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          addPanel,
                                          const SizedBox(height: 16),
                                          suggestionsPanel,
                                        ],
                                      ),
                                    ),
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
                            preferencesLink,
                            const SizedBox(height: 16),
                            addPanel,
                            const SizedBox(height: 20),
                            suggestionsPanel,
                            const SizedBox(height: 20),
                            dayPlan,
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
// Item types
// ─────────────────────────────────────────────────────────

/// Display text and icons for each [ScheduleItemType].
({
  String noun,
  String heading,
  String emptyText,
  IconData icon,
  String titleLabel,
  String detailsLabel,
}) _typeInfo(ScheduleItemType type) => switch (type) {
      ScheduleItemType.flight => (
          noun: 'flight',
          heading: 'Flights',
          emptyText: 'No flights added yet.',
          icon: Icons.flight_rounded,
          titleLabel: 'Flight (e.g. UA 123, ORD → JFK)',
          detailsLabel: 'Details (e.g. departs 8:05 AM)',
        ),
      ScheduleItemType.hotel => (
          noun: 'hotel',
          heading: 'Stay',
          emptyText: 'No hotel added yet.',
          icon: Icons.hotel_rounded,
          titleLabel: 'Hotel name',
          detailsLabel: 'Details (e.g. 1 bed)',
        ),
      ScheduleItemType.activity => (
          noun: 'activity',
          heading: 'Activities',
          emptyText: 'No activities planned yet.',
          icon: Icons.local_activity_rounded,
          titleLabel: 'Activity',
          detailsLabel: 'Details (e.g. time, tickets)',
        ),
    };

String _capitalized(String s) => s[0].toUpperCase() + s.substring(1);

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

/// A rounded inner card, used for day-plan entries and add buttons.
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

/// The final itinerary for [selectedDay]. Edit/remove controls (and Remove
/// day) appear only when their callback is set, i.e. for the admin.
/// Suggestions are listed in [_SuggestionsPanel] instead.
class _DayPlanPanel extends StatelessWidget {
  const _DayPlanPanel({
    required this.days,
    required this.selectedDay,
    required this.items,
    required this.attribution,
    required this.onSelectDay,
    required this.onDeleteDay,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final List<ScheduleDay> days;
  final ScheduleDay? selectedDay;
  final List<ScheduleItem> items;
  final String? Function(ScheduleItem) attribution;
  final ValueChanged<ScheduleDay> onSelectDay;
  final ValueChanged<ScheduleDay>? onDeleteDay;
  final ValueChanged<ScheduleItem>? onEditItem;
  final ValueChanged<ScheduleItem>? onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final day = selectedDay;
    if (day == null) {
      return _Panel(
        title: 'Day Plan',
        children: [
          Text('Nothing planned yet. Add a flight, hotel, or activity to start the schedule.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      );
    }

    final dayItems = items.where((i) => i.day == day.key);

    return _Panel(
      title: 'Day Plan',
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: _innerCard(),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const ValueKey('day-plan-dropdown'),
                    value: day.key,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    icon: const Icon(Icons.expand_more_rounded, color: AppColors.accentEnd),
                    style: AppTextStyles.body,
                    items: [
                      for (final d in days)
                        DropdownMenuItem(
                          value: d.key,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 16, color: AppColors.accentEnd),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(formatScheduleDay(d.date),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (key) {
                      for (final d in days) {
                        if (d.key == key) onSelectDay(d);
                      }
                    },
                  ),
                ),
              ),
            ),
            if (onDeleteDay case final onDeleteDay?)
              IconButton(
                tooltip: 'Remove day',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => onDeleteDay(day),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final type in ScheduleItemType.values) ...[
          _sectionHeader(type),
          const SizedBox(height: 8),
          ..._sectionBody(type, dayItems.where((i) => i.type == type).toList()),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _sectionHeader(ScheduleItemType type) {
    final info = _typeInfo(type);
    return Row(
      children: [
        Icon(info.icon, size: 18, color: AppColors.accentEnd),
        const SizedBox(width: 8),
        Expanded(
          child: Text(info.heading,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  List<Widget> _sectionBody(ScheduleItemType type, List<ScheduleItem> sectionItems) {
    if (sectionItems.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _innerCard(),
          child: Text(_typeInfo(type).emptyText, style: AppTextStyles.caption),
        ),
      ];
    }
    return [
      for (final item in sectionItems)
        _ScheduleItemCard(
          item: item,
          attribution: attribution(item),
          onEdit: onEditItem == null ? null : () => onEditItem!(item),
          onDelete: onDeleteItem == null ? null : () => onDeleteItem!(item),
        ),
    ];
  }
}

/// Every pending suggestion, across all days, labelled with its date and who
/// suggested it. The admin gets Approve / Reject; the member who suggested an
/// item can withdraw it; everyone else just sees what's pending.
class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({
    required this.suggestions,
    required this.attribution,
    required this.currentUserId,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
  });

  final List<ScheduleItem> suggestions;
  final String? Function(ScheduleItem) attribution;
  final String currentUserId;
  final ValueChanged<ScheduleItem>? onApprove;
  final ValueChanged<ScheduleItem>? onReject;
  final ValueChanged<ScheduleItem>? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final sorted = [...suggestions]..sort((a, b) => a.day.compareTo(b.day));
    return _Panel(
      title: 'Suggestions',
      subtitle: onApprove != null
          ? 'Approve to add to the Day Plan, or reject.'
          : 'Waiting for the trip admin to approve.',
      children: [
        if (sorted.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _innerCard(),
            child: const Text('No suggestions pending.', style: AppTextStyles.caption),
          ),
        for (final item in sorted)
          _SuggestionCard(
            item: item,
            attribution: attribution(item),
            onApprove: onApprove == null ? null : () => onApprove!(item),
            onReject: onReject == null ? null : () => onReject!(item),
            onWithdraw: onWithdraw != null && item.addedBy == currentUserId
                ? () => onWithdraw!(item)
                : null,
          ),
      ],
    );
  }
}

/// The three ways to add to the trip. Each opens a form that asks for the
/// date along with the details. The admin's result shows up in the Day Plan;
/// a member's ([suggest]) goes to Suggestions.
class _AddToTripPanel extends StatelessWidget {
  const _AddToTripPanel({required this.suggest, required this.onAdd});

  final bool suggest;
  final ValueChanged<ScheduleItemType> onAdd;

  static const _order = [
    ScheduleItemType.activity,
    ScheduleItemType.flight,
    ScheduleItemType.hotel,
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Add to Trip',
      subtitle: suggest
          ? 'Pick a date and the details — the trip admin approves it for the Day Plan.'
          : 'Pick a date and the details — it shows up in the Day Plan.',
      children: [
        for (final type in _order)
          _AddTile(
            icon: _typeInfo(type).icon,
            label: '${suggest ? 'Suggest' : 'Add'} ${_capitalized(_typeInfo(type).noun)}',
            onTap: () => onAdd(type),
          ),
      ],
    );
  }
}

/// Title, optional details, and who added it.
class _ItemText extends StatelessWidget {
  const _ItemText({required this.item, required this.attribution});

  final ScheduleItem item;
  final String? attribution;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: AppTextStyles.body),
        if (item.details.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(item.details, style: AppTextStyles.caption),
        ],
        if (attribution != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(attribution!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ScheduleItemCard extends StatelessWidget {
  const _ScheduleItemCard({
    required this.item,
    required this.attribution,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleItem item;
  final String? attribution;

  /// Null hides the control (members can't change the itinerary).
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(14, 10, onEdit == null && onDelete == null ? 14 : 4, 10),
      decoration: _innerCard(),
      child: Row(
        children: [
          Icon(_typeInfo(item.type).icon, color: AppColors.accentEnd, size: 20),
          const SizedBox(width: 12),
          Expanded(child: _ItemText(item: item, attribution: attribution)),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
              onPressed: onEdit,
            ),
          if (onDelete != null)
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

/// A pending suggestion: what, which day, who suggested it, and whichever of
/// Approve / Reject / Withdraw the viewer may use (null hides it).
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.item,
    required this.attribution,
    required this.onApprove,
    required this.onReject,
    required this.onWithdraw,
  });

  final ScheduleItem item;
  final String? attribution;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(item.day);
    final hasActions = onApprove != null || onReject != null || onWithdraw != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(14, 10, hasActions ? 4 : 14, 10),
      decoration: _innerCard(),
      child: Row(
        children: [
          Icon(_typeInfo(item.type).icon, color: AppColors.accentEnd, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date != null) ...[
                  Text(formatScheduleDay(date),
                      style: AppTextStyles.caption.copyWith(color: AppColors.accentEnd)),
                  const SizedBox(height: 2),
                ],
                _ItemText(item: item, attribution: attribution),
              ],
            ),
          ),
          if (onApprove != null)
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(Icons.check_rounded, color: AppColors.accentEnd, size: 20),
              onPressed: onApprove,
            ),
          if (onReject != null)
            IconButton(
              tooltip: 'Reject',
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
              onPressed: onReject,
            ),
          if (onWithdraw != null)
            IconButton(
              tooltip: 'Withdraw',
              icon: const Icon(Icons.undo_rounded, color: AppColors.textMuted, size: 18),
              onPressed: onWithdraw,
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
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
                Icon(icon, color: AppColors.accentEnd, size: 20),
                const SizedBox(width: 12),
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

Future<({DateTime date, String title, String details})?> _showItemDialog(
  BuildContext context, {
  required ScheduleItemType type,
  required DateTime initialDate,
  bool suggest = false,
  String initialTitle = '',
  String initialDetails = '',
  ({String label, VoidCallback onTap})? search,
}) {
  final info = _typeInfo(type);
  final isEdit = initialTitle.isNotEmpty;
  final titleController = TextEditingController(text: initialTitle);
  final detailsController = TextEditingController(text: initialDetails);
  var date = initialDate;

  return showDialog<({DateTime date, String title, String details})>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: AppDecorations.glassCard(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${isEdit ? 'Edit' : suggest ? 'Suggest' : 'Add'} ${_capitalized(info.noun)}',
                  style: AppTextStyles.title),
              const SizedBox(height: 18),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('item-date'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 3),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: _innerCard(),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: AppColors.accentEnd, size: 18),
                        const SizedBox(width: 12),
                        Expanded(child: Text(formatScheduleDay(date), style: AppTextStyles.body)),
                        const Icon(Icons.edit_calendar_rounded,
                            color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                autofocus: true,
                style: AppTextStyles.body,
                decoration: AppDecorations.inputDecoration(
                  label: info.titleLabel,
                  prefixIcon: info.icon,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                style: AppTextStyles.body,
                decoration: AppDecorations.inputDecoration(label: info.detailsLabel),
              ),
              if (search != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      search.onTap();
                    },
                    icon: const Icon(Icons.search_rounded, color: AppColors.accentEnd, size: 18),
                    label: Text(search.label,
                        style: AppTextStyles.body.copyWith(color: AppColors.accentEnd)),
                  ),
                ),
              ],
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
                        Navigator.of(dialogContext).pop((
                          date: date,
                          title: title,
                          details: detailsController.text.trim(),
                        ));
                      },
                      label: suggest ? 'Suggest' : 'Save',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
