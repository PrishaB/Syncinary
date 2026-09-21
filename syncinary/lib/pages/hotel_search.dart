import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HotelSearch extends StatelessWidget {
  const HotelSearch({
    super.key,
    required this.initialResults,
  });

  final List<dynamic> initialResults;

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
        title: Text(
          'Hotel Results',
          style: AppTextStyles.title,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: initialResults.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hotel_outlined,
                      size: 64,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hotels found.',
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                itemCount: initialResults.length,
                itemBuilder: (_, i) {
                  final hotel = initialResults[i];

                  final name =
                      hotel['name']?.toString() ?? 'Unknown Hotel';

                  final rating = hotel['overall_rating'];

                  final reviews = hotel['reviews'];

                  final price =
                      hotel['rate_per_night']?['lowest'];

                  final hotelClass = hotel['hotel_class'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                              child: const Icon(
                                Icons.hotel_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: AppTextStyles.title.copyWith(
                                      fontSize: 17,
                                    ),
                                  ),

                                  const SizedBox(height: 5),

                                  if (rating != null)
                                    Text(
                                      '⭐ $rating'
                                      '${reviews != null ? ' ($reviews reviews)' : ''}',
                                      style: AppTextStyles.caption,
                                    ),

                                  if (hotelClass != null)
                                    Text(
                                      '$hotelClass-star hotel',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            if (price != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentStart
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  price.toString(),
                                  style: AppTextStyles.button.copyWith(
                                    color: AppColors.accentEnd,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}