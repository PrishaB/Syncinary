import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/page_body.dart';

class HotelSearch extends StatelessWidget {
  const HotelSearch({super.key, required this.initialResults});

  final List<dynamic> initialResults;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const GradientAppBar(title: 'Hotel Results'),
    body: PageBody(
      maxWidth: 880,
      child: initialResults.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hotel_outlined,
                      size: 56,
                      color: AppColors.accentEnd,
                    ),
                    SizedBox(height: 16),
                    Text('No hotels found.', style: AppTextStyles.subtitle),
                    SizedBox(height: 8),
                    Text(
                      'Try another destination or travel dates.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              itemCount: initialResults.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, i) {
                final hotel = initialResults[i];
                final name = hotel['name']?.toString() ?? 'Unknown Hotel';
                final rating = hotel['overall_rating'];
                final reviews = hotel['reviews'];
                final price = hotel['rate_per_night']?['lowest'];
                final hotelClass = hotel['hotel_class'];
                return Container(
                  decoration: AppDecorations.glassCard(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.hotel_rounded,
                              color: AppColors.accentEnd,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: AppTextStyles.title.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (rating != null)
                                  Text(
                                    '⭐ $rating${reviews != null ? ' ($reviews reviews)' : ''}',
                                    style: AppTextStyles.caption,
                                  ),
                                if (hotelClass != null)
                                  Text(
                                    '$hotelClass-star hotel',
                                    style: AppTextStyles.caption,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (price != null) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              price.toString(),
                              style: AppTextStyles.title.copyWith(
                                color: AppColors.accentEnd,
                              ),
                            ),
                            const Text(
                              'per night',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    ),
  );
}
