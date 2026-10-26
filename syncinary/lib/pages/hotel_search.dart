import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_panel.dart';

/// Hotel results returned by the existing /hotels proxy endpoint.
///
/// [onHotelSelected] adds a hotel to the itinerary.
/// [onHotelBook] starts the separate booking flow.
class HotelSearch extends StatefulWidget {
  const HotelSearch({
    super.key,
    required this.initialResults,
    this.onHotelSelected,
    this.onHotelBook,
  });

  final List<dynamic> initialResults;
  final ValueChanged<Map<String, dynamic>>? onHotelSelected;
  final ValueChanged<Map<String, dynamic>>? onHotelBook;

  @override
  State<HotelSearch> createState() => _HotelSearchState();
}

enum _HotelSort { recommended, priceLow, priceHigh, ratingHigh }

class _HotelSearchState extends State<HotelSearch> {
  _HotelSort _sort = _HotelSort.recommended;

  List<Map<String, dynamic>> get _hotels {
    final hotels = widget.initialResults
        .whereType<Map>()
        .map((hotel) => Map<String, dynamic>.from(hotel))
        .toList();

    if (_sort == _HotelSort.recommended) return hotels;

    // Keep hotels with missing sort values at the end, regardless of direction.
    double? value(Map<String, dynamic> hotel) {
      switch (_sort) {
        case _HotelSort.priceLow:
        case _HotelSort.priceHigh:
          return _priceNumber(hotel);
        case _HotelSort.ratingHigh:
          return _number(hotel['overall_rating']);
        case _HotelSort.recommended:
          return null;
      }
    }

    hotels.sort((a, b) {
      final av = value(a);
      final bv = value(b);
      if (av == null) return bv == null ? 0 : 1;
      if (bv == null) return -1;
      return _sort == _HotelSort.priceLow ? av.compareTo(bv) : bv.compareTo(av);
    });
    return hotels;
  }

  static double? _number(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw == null) return null;
    final cleaned = raw.toString().replaceAll(RegExp(r'[^\d.\-]'), '');
    return double.tryParse(cleaned);
  }

  static String? _nonEmpty(dynamic raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _hotelClass(dynamic raw) {
    final value = _nonEmpty(raw);
    if (value == null) return null;
    // Test fixtures may use 4; SerpApi may provide '4-star hotel'.
    if (num.tryParse(value) != null) return '$value-star hotel';
    return value;
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static double? _priceNumber(Map<String, dynamic> hotel) {
    final rate = _asMap(hotel['rate_per_night']);
    return _number(rate['extracted_lowest']) ??
        _number(hotel['extracted_price']) ??
        _number(rate['lowest']);
  }

  static String? _nightlyPrice(Map<String, dynamic> hotel) {
    final rate = _asMap(hotel['rate_per_night']);
    return _nonEmpty(rate['lowest']) ??
        _formatUsd(_number(rate['extracted_lowest'])) ??
        _formatUsd(_number(hotel['extracted_price']));
  }

  static String? _formatUsd(double? value) {
    if (value == null) return null;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '\$$formatted';
  }

  static String? _totalPrice(Map<String, dynamic> hotel) {
    final total = _asMap(hotel['total_rate']);
    return _nonEmpty(total['lowest']) ??
        _formatUsd(_number(total['extracted_lowest']));
  }

  static List<String> _amenities(Map<String, dynamic> hotel) {
    final raw = hotel['amenities'];
    if (raw is! List) return const [];
    return raw.map(_nonEmpty).whereType<String>().take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hotels = _hotels;
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
        title: Text('Hotel Results', style: AppTextStyles.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: hotels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hotel_outlined,
                          size: 64,
                          color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No hotels found.',
                          style: AppTextStyles.subtitle
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth > 850 ? 850.0 : constraints.maxWidth;
                    return Center(
                      child: SizedBox(
                        width: maxWidth,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 112, 16, 30),
                          itemCount: hotels.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) return _header(hotels.length);
                            final hotel = hotels[index - 1];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _hotelCard(hotel),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _header(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find your perfect stay', style: AppTextStyles.headline.copyWith(fontSize: 24)),
          const SizedBox(height: 6),
          Text('Compare hotels and choose your stay', style: AppTextStyles.subtitle),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('$count hotels found',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<_HotelSort>(
                  value: _sort,
                  isDense: true,
                  dropdownColor: AppColors.surfaceLight,
                  iconEnabledColor: AppColors.accentEnd,
                  style: AppTextStyles.body.copyWith(color: AppColors.accentEnd),
                  items: const [
                    DropdownMenuItem(value: _HotelSort.recommended, child: Text('Recommended')),
                    DropdownMenuItem(value: _HotelSort.priceLow, child: Text('Price: Low to High')),
                    DropdownMenuItem(value: _HotelSort.priceHigh, child: Text('Price: High to Low')),
                    DropdownMenuItem(value: _HotelSort.ratingHigh, child: Text('Highest Rated')),
                  ],
                  onChanged: (sort) {
                    if (sort != null) setState(() => _sort = sort);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hotelCard(Map<String, dynamic> hotel) {
    final name = _nonEmpty(hotel['name']) ?? 'Unknown Hotel';
    final rating = _nonEmpty(hotel['overall_rating']);
    final reviews = _nonEmpty(hotel['reviews']);
    final hotelClass = _hotelClass(hotel['hotel_class']);
    final nightlyPrice = _nightlyPrice(hotel);
    final totalPrice = _totalPrice(hotel);
    final amenities = _amenities(hotel);

    return Container(
      decoration: AppDecorations.glassCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.apartment_rounded,
                    size: 26, color: AppColors.accentMid),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.title.copyWith(fontSize: 17)),
                    if (hotelClass != null) ...[
                      const SizedBox(height: 4),
                      Text(hotelClass, style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      )),
                    ],
                    if (rating != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: [
                          const Icon(Icons.star_rounded, size: 17, color: AppColors.warning),
                          Text(rating, style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                          if (reviews != null)
                            Text('($reviews reviews)', style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            )),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenities.map((amenity) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(amenity, style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                )),
              )).toList(),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nightlyPrice != null)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 5,
                  children: [
                    Text(nightlyPrice, style: AppTextStyles.title.copyWith(
                      color: AppColors.accentEnd,
                      fontSize: 23,
                    )),
                    Text('/ night', style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    )),
                  ],
                )
              else
                Text('Price unavailable', style: AppTextStyles.caption),
              if (totalPrice != null) ...[
                const SizedBox(height: 5),
                Text('$totalPrice total for stay',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    )),
              ],
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 370;
              final addButton = Tooltip(
                message: widget.onHotelSelected == null
                    ? 'Itinerary selection is not connected yet'
                    : 'Add hotel to your itinerary',
                child: OutlinedButton.icon(
                  onPressed: widget.onHotelSelected == null
                      ? null
                      : () => widget.onHotelSelected!(hotel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentEnd,
                    side: const BorderSide(color: AppColors.accentEnd),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add to Itinerary'),
                ),
              );
              final bookButton = Tooltip(
                message: widget.onHotelBook == null
                    ? 'Booking is not connected yet'
                    : 'Book this hotel',
                child: ElevatedButton.icon(
                  onPressed: widget.onHotelBook == null
                      ? null
                      : () => widget.onHotelBook!(hotel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentStart,
                    foregroundColor: AppColors.textPrimary,
                    disabledBackgroundColor: AppColors.surfaceLight,
                    disabledForegroundColor: AppColors.textMuted,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Book'),
                ),
              );
              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    addButton,
                    const SizedBox(height: 10),
                    bookButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: addButton),
                  const SizedBox(width: 10),
                  Expanded(child: bookButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
