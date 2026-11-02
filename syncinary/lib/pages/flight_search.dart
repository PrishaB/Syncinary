// TODO: rename snake_case types, then drop this ignore (follow-up to #117).
// ignore_for_file: camel_case_types
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/suggestions_section.dart';
import '../widgets/settings_panel.dart';
import 'amadeus_service.dart';

class flight_search extends StatefulWidget {
  const flight_search({
    super.key,
    required this.title,
    required this.initialResults,
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.returnDate,
    this.adults = 1,
    this.isReturnLeg = false,
    this.onFlightSelected,
    this.recommendationService,
    this.searchContext,
  });

  final String title;
  final List<dynamic> initialResults;
  final String origin;
  final String destination;
  final String departureDate;
  final String? returnDate;
  final int adults;

  /// Called when a flight is added to the itinerary.
  /// Without a callback, the Add to Itinerary button is disabled.
  final ValueChanged<Map<String, dynamic>>? onFlightSelected;

  /// True when this screen is showing return-leg options for a round trip
  /// (as opposed to the initial outbound-leg list). Tapping a card here
  /// goes straight to booking instead of fetching another leg.
  final bool isReturnLeg;

  // Both optional and only meaningful together (FR-104): when a caller
  // supplies neither, the suggestions section is omitted entirely and this
  // page behaves exactly as it did before that feature existed.
  final RecommendationService? recommendationService;
  final SearchContext? searchContext;

  @override
  State<flight_search> createState() => _flightSearchState();
}

class _flightSearchState extends State<flight_search> {
  bool _busy = false;

  bool get _isRoundTripOutbound =>
      widget.returnDate != null && !widget.isReturnLeg;

  Future<void> _handleOfferTap(dynamic offer) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (_isRoundTripOutbound) {
        final departureToken = offer['departure_token'] as String?;
        if (departureToken == null) {
          throw Exception('This offer has no departure_token.');
        }
        final returnResults = await AmadeusService().searchReturnFlights(
          origin: widget.origin,
          destination: widget.destination,
          departureDate: widget.departureDate,
          returnDate: widget.returnDate!,
          departureToken: departureToken,
          adults: widget.adults,
        );
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => flight_search(
              title: 'Select Return Flight',
              initialResults: returnResults,
              origin: widget.origin,
              destination: widget.destination,
              departureDate: widget.departureDate,
              returnDate: widget.returnDate,
              adults: widget.adults,
              isReturnLeg: true,
              onFlightSelected: widget.onFlightSelected,
            ),
          ),
        );
        return;
      }

      // Final leg (one-way, or the return leg of a round trip) — go to booking.
      final bookingToken = offer['booking_token'] as String?;
      if (bookingToken == null) {
        throw Exception('This offer has no booking_token.');
      }
      final bookingOptions = await AmadeusService().getBookingOptions(
        origin: widget.origin,
        destination: widget.destination,
        departureDate: widget.departureDate,
        bookingToken: bookingToken,
        adults: widget.adults,
        returnDate: widget.returnDate,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _showBookingSheet(bookingOptions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showBookingSheet(List<dynamic> bookingOptions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        if (bookingOptions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No booking options returned.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  label: 'Close',
                  icon: Icons.close_rounded,
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Book this flight', style: AppTextStyles.title),
                const SizedBox(height: 16),
                ...bookingOptions.map(
                  (raw) => _BookingOptionTile(
                    option: raw,
                    origin: widget.origin,
                    destination: widget.destination,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.recommendationService;
    final searchCtx = widget.searchContext;
    final showSuggestions = service != null && searchCtx != null;
    final results = widget.initialResults;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: const [SettingsButton()],
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
        title: Text(widget.title, style: AppTextStyles.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            Column(
              children: [
                // Suggestions sit above the flight list (or the empty message)
                // and load independently, so a slow/failed recommendation never
                // blocks the flights the user already searched for.
                if (showSuggestions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 0),
                    child: SuggestionsSection(
                      service: service,
                      searchContext: searchCtx,
                    ),
                  ),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flight_outlined,
                                size: 64,
                                color: AppColors.textMuted.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No flights found.',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                       : ListView.builder(
                           padding: EdgeInsets.fromLTRB(
                             16,
                             showSuggestions ? 12 : 100,
                             16,
                             24,
                           ),
                           itemCount: results.length,
                           itemBuilder: (_, i) {
                             final offer = results[i];
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 16),
                               child: _FlightCard(
                                 offer: offer,
                                 isLoading: _busy,
                                 buttonLabel: _isRoundTripOutbound
                                     ? 'Select Outbound'
                                     : widget.isReturnLeg
                                         ? 'Select Return'
                                         : 'Select Flight',
                                 onSelect: () => _handleOfferTap(offer),
                                 onAddToItinerary: widget.onFlightSelected == null || offer is! Map
                                     ? null
                                     : () => widget.onFlightSelected!(
                                           Map<String, dynamic>.from(offer),
                                         ),
                               ),
                             );
                           },
                         ),
                ),
              ],
            ),
            if (_busy)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Redesigned flight result card. Uses only data already in the offer.
class _FlightCard extends StatelessWidget {
  const _FlightCard({
    required this.offer,
    required this.onSelect,
    this.onAddToItinerary,
    required this.buttonLabel,
    required this.isLoading,
  });

  final dynamic offer;
  final VoidCallback onSelect;
  final VoidCallback? onAddToItinerary;
  final String buttonLabel;
  final bool isLoading;

  String _formatTime(dynamic value) {
    if (value == null) return '--:--';
    final raw = value.toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${parsed.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDuration(dynamic value) {
    if (value is! num) return '';
    final minutes = value.toInt();
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '${remainder}m';
    if (remainder == 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }

  @override
  Widget build(BuildContext context) {
    final flights = offer['flights'] as List<dynamic>? ?? [];
    if (flights.isEmpty) return const SizedBox.shrink();

    final first = flights.first;
    final last = flights.last;
    final departure = first['departure_airport'];
    final arrival = last['arrival_airport'];
    final origin = departure?['id']?.toString() ?? '---';
    final destination = arrival?['id']?.toString() ?? '---';
    final departureTime = _formatTime(departure?['time']);
    final arrivalTime = _formatTime(arrival?['time']);
    final airline = first['airline']?.toString() ?? 'Airline';
    final duration = _formatDuration(offer['total_duration']);
    final stops = flights.length - 1;
    final stopLabel = stops == 0
        ? 'Nonstop'
        : '$stops ${stops == 1 ? 'stop' : 'stops'}';
    final price = offer['price']?.toString() ?? 'N/A';

    return Container(
      decoration: AppDecorations.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flight_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(airline,
                    style: AppTextStyles.title.copyWith(fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentStart.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(stopLabel,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentEnd)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(departureTime,
                        style: AppTextStyles.title.copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(origin, style: AppTextStyles.subtitle),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Text(duration, style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 7,
                            color: AppColors.accentStart),
                        Expanded(child: Container(
                            height: 1, color: AppColors.textMuted)),
                        Icon(Icons.flight_rounded, size: 18,
                            color: AppColors.accentEnd),
                        Expanded(child: Container(
                            height: 1, color: AppColors.textMuted)),
                        Icon(Icons.circle, size: 7,
                            color: AppColors.accentStart),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(arrivalTime,
                        style: AppTextStyles.title.copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(destination, style: AppTextStyles.subtitle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: AppColors.textMuted.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\$$price',
                  style: AppTextStyles.title.copyWith(
                      fontSize: 22, color: AppColors.accentEnd)),
              const SizedBox(height: 4),
              Text('Listed price', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final addButton = OutlinedButton.icon(
                onPressed: isLoading ? null : onAddToItinerary,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add to Itinerary'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentEnd,
                  side: const BorderSide(color: AppColors.accentEnd),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              final selectButton = IgnorePointer(
                ignoring: isLoading,
                child: Opacity(
                  opacity: isLoading ? 0.5 : 1,
                  child: GradientButton(
                    onPressed: onSelect,
                    label: buttonLabel,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    addButton,
                    const SizedBox(height: 10),
                    selectButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: addButton),
                  const SizedBox(width: 10),
                  Expanded(child: selectButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One row in the booking bottom sheet. Handles both booking-option shapes:
/// a direct `url` you can open right away, and a `booking_request` that
/// needs a POST (which the app can't just open as a link) — that case
/// falls back to a Google Flights search link instead.
class _BookingOptionTile extends StatelessWidget {
  const _BookingOptionTile({
    required this.option,
    required this.origin,
    required this.destination,
  });

  final dynamic option;
  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    // SerpApi nests round-trip booking info under "together"; one-way
    // options may be flat. Fall back gracefully either shape.
    final data = (option is Map && option['together'] != null)
        ? option['together']
        : option;

    final bookWith = data?['book_with'] as String? ?? 'Unknown provider';
    final price = data?['price'];
    final directUrl = data?['booking_request']?['url'] as String?;
    final hasPostData = data?['booking_request']?['post_data'] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: AppDecorations.glassCard(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            title: Text(bookWith, style: AppTextStyles.body),
            subtitle: price != null
                ? Text('\$$price', style: AppTextStyles.caption)
                : null,
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () async {
              Uri? uri;
              if (directUrl != null && !hasPostData) {
                uri = Uri.tryParse(directUrl);
              } else {
                // Fallback: this booking option needs a POST checkout flow we
                // can't open directly, so send the user to a Google Flights
                // search instead.
                uri = Uri.parse(
                  'https://www.google.com/travel/flights?q=flights%20from%20$origin%20to%20$destination',
                );
              }
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      ),
    );
  }
}
