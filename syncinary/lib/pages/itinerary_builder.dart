import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'flight_search.dart';
import 'login_page.dart';
import 'groups/my_groups_page.dart';
import '../theme/app_theme.dart';
 
enum SearchType { flights, hotels }
 
class itinerary_builder extends StatefulWidget {
  const itinerary_builder({super.key});
 
  @override
  State<itinerary_builder> createState() => _itineraryState();
}
 
class _itineraryState extends State<itinerary_builder> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
 
  int currentDisplay = 0;
  DateTime? _departureDate;
  DateTime? _returnDate;
  int _passengers = 1;
  SearchType _searchType = SearchType.flights;
  bool _loading = false;
 
  void updateDisplay(int display) {
    setState(() {
      currentDisplay = display;
    });
  }
 
  @override
  Widget build(BuildContext context) {
    // ── Step labels & icons for the nav bar ──
    final steps = [
      _StepInfo(Icons.flight_takeoff_rounded, 'From', 0),
      _StepInfo(Icons.flight_land_rounded, 'Destination', 1),
      _StepInfo(Icons.calendar_month_rounded, 'Dates', 2),
      _StepInfo(Icons.group_rounded, 'Travelers', 3),
    ];
 
    final List<Widget> screens = [
      // ── Screen 0: Origin ──
      _buildStepBody(
        icon: Icons.flight_takeoff_rounded,
        heading: 'Where are you starting from?',
        subtitle: 'Enter your departure city or airport code',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _startController,
              style: AppTextStyles.body,
              decoration: AppDecorations.inputDecoration(
                label: 'Origin (e.g. JFK)',
                prefixIcon: Icons.location_on_outlined,
                suffixIcon: Icons.search,
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              onPressed: () => updateDisplay(1),
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ),
      ),
 
      // ── Screen 1: Destination ──
      _buildStepBody(
        icon: Icons.flight_land_rounded,
        heading: 'Choose your destination',
        subtitle: 'Enter the city or airport code you\'re flying to',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _endController,
              style: AppTextStyles.body,
              decoration: AppDecorations.inputDecoration(
                label: 'Destination (e.g. LAX)',
                prefixIcon: Icons.pin_drop_outlined,
                suffixIcon: Icons.search,
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              onPressed: () => updateDisplay(2),
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ),
      ),
 
      // ── Screen 2: Dates ──
      _buildStepBody(
        icon: Icons.calendar_month_rounded,
        heading: 'Pick your travel dates',
        subtitle: 'Select departure and arrival dates for your trip',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Departure date
            _DatePickerTile(
              icon: Icons.event_rounded,
              label: _departureDate == null
                  ? 'No departure date selected'
                  : 'Departure: ${_departureDate!.toLocal().toString().split(' ')[0]}',
              isSet: _departureDate != null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _departureDate = picked;
                    // Keep return date valid relative to the new departure date.
                    if (_returnDate != null && _returnDate!.isBefore(picked)) {
                      _returnDate = null;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            // Return / arrival date
            _DatePickerTile(
              icon: Icons.event_available_rounded,
              label: _returnDate == null
                  ? 'No return date selected'
                  : 'Return: ${_returnDate!.toLocal().toString().split(' ')[0]}',
              isSet: _returnDate != null,
              onTap: () async {
                final firstAvailable = _departureDate ?? DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: firstAvailable,
                  firstDate: firstAvailable,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _returnDate = picked);
              },
            ),
            const SizedBox(height: 28),
            GradientButton(
              onPressed: () => updateDisplay(3),
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ),
      ),
 
      //Enter # travellers and want to search for hotel or flight
      _buildStepBody(
        icon: Icons.group_rounded,
        heading: 'Who\'s traveling?',
        subtitle: 'Set passenger count and what you\'re searching for',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //only allow user to enter # passengers with step counter
            //might consider adding adults/children diffrentiator later
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '$_passengers ${_passengers == 1 ? 'passenger' : 'passengers'}',
                      style: AppTextStyles.body,
                    ),
                  ),
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    onTap: _passengers > 1
                        ? () => setState(() => _passengers--)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  _StepperButton(
                    icon: Icons.add_rounded,
                    onTap: _passengers < 9
                        ? () => setState(() => _passengers++)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            //toggle between searching for flights or hotels
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeToggleButton(
                      icon: Icons.flight_rounded,
                      label: 'Flights',
                      isActive: _searchType == SearchType.flights,
                      onTap: () =>
                          setState(() => _searchType = SearchType.flights),
                    ),
                  ),
                  Expanded(
                    child: _TypeToggleButton(
                      icon: Icons.hotel_rounded,
                      label: 'Hotels',
                      isActive: _searchType == SearchType.hotels,
                      onTap: () =>
                          setState(() => _searchType = SearchType.hotels),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              onPressed: _loading
                  ? null
                  : () async {
                      if (_startController.text.isEmpty ||
                          _endController.text.isEmpty ||
                          _departureDate == null) {
                        return;
                      }
                      setState(() => _loading = true);
                      //haven't wired serpapi yet so just shows the empty
                      //results state on the search screen for now.
                      await Future<void>.delayed(
                          const Duration(milliseconds: 400));
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => flight_search(
                              title: _searchType == SearchType.flights
                                  ? 'Flight Results'
                                  : 'Hotel Results',
                              initialResults: const [],
                            ),
                          ),
                        );
                      }
                      if (context.mounted) setState(() => _loading = false);
                    },
              label: _searchType == SearchType.flights
                  ? 'Search Flights'
                  : 'Search Hotels',
              icon: Icons.search_rounded,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    ];
 
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface.withValues(alpha: 0.95),
                AppColors.surface.withValues(alpha: 0.80),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: steps.map((step) {
              final isActive = currentDisplay == step.index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _NavChip(
                  icon: step.icon,
                  label: step.label,
                  isActive: isActive,
                  onTap: () => updateDisplay(step.index),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_rounded, color: AppColors.textMuted),
            tooltip: 'My Groups',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyGroupsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
            tooltip: 'Log out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
 
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(currentDisplay),
            child: screens[currentDisplay],
          ),
        ),
      ),
    );
  }
 
  /// Builds the shared layout wrapper for each step screen.
  Widget _buildStepBody({
    required IconData icon,
    required String heading,
    required String subtitle,
    required Widget child,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentStart.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 28),
              Text(heading, style: AppTextStyles.headline, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle, style: AppTextStyles.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 36),
              // Glass card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: AppDecorations.glassCard(),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 
// ─────────────────────────────────────────────────────────
// Private helpers (no logic — pure presentation)
// ─────────────────────────────────────────────────────────
 
class _StepInfo {
  _StepInfo(this.icon, this.label, this.index);
  final IconData icon;
  final String label;
  final int index;
}
 
/// A pill-shaped nav chip for the app bar.
class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });
 
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.brandGradient : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? null
              : Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.navLabel.copyWith(
                color: isActive ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
///a tappable tile used for the departure/return date pickers.
class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.icon,
    required this.label,
    required this.isSet,
    required this.onTap,
  });
 
  final IconData icon;
  final String label;
  final bool isSet;
  final VoidCallback onTap;
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSet ? AppColors.accentEnd : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: isSet ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
///small circular +/- button used by the passenger stepper
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
 
  final IconData icon;
  final VoidCallback? onTap;
 
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.brandGradient : null,
          color: enabled ? null : AppColors.surface,
          shape: BoxShape.circle,
          border: enabled ? null : Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}
 
///one half of the flights/hotels segmented toggl
class _TypeToggleButton extends StatelessWidget {
  const _TypeToggleButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });
 
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.navLabel.copyWith(
                color: isActive ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}