import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
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
  });
 
  final String title;
  final List<dynamic> initialResults;
  final String origin;
  final String destination;
  final String departureDate;
  final String? returnDate;
  final int adults;
 
  /// True when this screen is showing return-leg options for a round trip
  /// (as opposed to the initial outbound-leg list). Tapping a card here
  /// goes straight to booking instead of fetching another leg.
  final bool isReturnLeg;
 
  @override
  State<flight_search> createState() => _flightSearchState();
}
 
class _flightSearchState extends State<flight_search> {
  bool _busy = false;
 
  String _formatDuration(int? minutes) {
    if (minutes == null) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
 
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
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
                Text('No booking options returned.',
                    style: AppTextStyles.subtitle),
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
                ...bookingOptions.map((raw) => _BookingOptionTile(
                      option: raw,
                      origin: widget.origin,
                      destination: widget.destination,
                    )),
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
            widget.initialResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flight_outlined,
                            size: 64,
                            color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('No flights found.',
                            style: AppTextStyles.subtitle
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                    itemCount: widget.initialResults.length,
                    itemBuilder: (_, i) {
                      final offer = widget.initialResults[i];
                      final flights = offer['flights'] as List<dynamic>;
                      final first = flights.first;
                      final dep = first['departure_airport']['id'];
                      final arr = flights.last['arrival_airport']['id'];
                      final time = first['departure_airport']['time'];
                      final price = offer['price'];
                      final airline = first['airline'] as String?;
                      final stops = flights.length - 1;
                      final duration =
                          _formatDuration(offer['total_duration'] as int?);
 
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _handleOfferTap(offer),
                          child: Container(
                            decoration: AppDecorations.glassCard(),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.brandGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.flight_rounded,
                                        color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('$dep  →  $arr',
                                            style: AppTextStyles.title
                                                .copyWith(fontSize: 17)),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (airline != null &&
                                                airline.isNotEmpty)
                                              airline,
                                            'Departs $time',
                                          ].join(' · '),
                                          style: AppTextStyles.caption,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (duration.isNotEmpty) duration,
                                            stops == 0
                                                ? 'Nonstop'
                                                : '$stops ${stops == 1 ? 'stop' : 'stops'}',
                                          ].join(' · '),
                                          style: AppTextStyles.caption
                                              .copyWith(
                                                  color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentStart
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('\$$price',
                                        style: AppTextStyles.button.copyWith(
                                          color: AppColors.accentEnd,
                                          fontSize: 15,
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
 