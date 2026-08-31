import 'package:flutter/material.dart';
import 'amadeus_service.dart';
import 'flight_search.dart';
import '../theme/app_theme.dart';

class itinerary_builder extends StatefulWidget {
  const itinerary_builder({super.key});

  @override
  State<itinerary_builder> createState() => _itineraryState();

}

class _itineraryState extends State<itinerary_builder> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final _amadeus = AmadeusService();

  int currentDisplay = 0;
  DateTime? _departureDate;
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
        subtitle: 'Select a departure date for your trip',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected date display
            Container(
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
                    Icons.event_rounded,
                    color: _departureDate != null
                        ? AppColors.accentEnd
                        : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _departureDate == null
                        ? 'No departure date selected'
                        : 'Departure: ${_departureDate!.toLocal().toString().split(' ')[0]}',
                    style: AppTextStyles.body.copyWith(
                      color: _departureDate != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _departureDate = picked);
              },
              label: 'Pick Departure Date',
              icon: Icons.date_range_rounded,
            ),
            const SizedBox(height: 14),
            GradientButton(
              onPressed: _loading ? null : () async {
                if (_startController.text.isEmpty ||
                    _endController.text.isEmpty ||
                    _departureDate == null) {
                  return;
                }
                setState(() => _loading = true);
                try {
                  final date = _departureDate!.toLocal().toString().split(' ')[0];
                  final results = await _amadeus.searchFlights(
                    origin: _startController.text.trim().toUpperCase(),
                    destination: _endController.text.trim().toUpperCase(),
                    departureDate: date,
                  );
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => flight_search(
                          title: 'Flight Results',
                          initialResults: results,
                        ),
                      ),
                    );
                  }
                } finally {
                  setState(() => _loading = false);
                }
              },
              label: 'Search Flights',
              icon: Icons.search_rounded,
              isLoading: _loading,
            ),
          ],
        ),
      )
      
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
        title: Row(
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
