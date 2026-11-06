import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_panel.dart';

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
        actions: const [SettingsButton()],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.of(context).surface.withValues(alpha: 0.95),
                AppColors.of(context).surface.withValues(alpha: 0.80),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Text(
          'Hotel Results',
          style: AppTextStyles.of(context).title,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.of(context).backgroundGradient,
        ),
        child: initialResults.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hotel_outlined,
                      size: 64,
                      color: AppColors.of(context).textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hotels found.',
                      style: AppTextStyles.of(context).subtitle.copyWith(
                        color: AppColors.of(context).textMuted,
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
                      decoration: AppDecorations.glassCard(context),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppColors.of(context).brandGradient,
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
                                    style: AppTextStyles.of(context).title.copyWith(
                                      fontSize: 17,
                                    ),
                                  ),

                                  const SizedBox(height: 5),

                                  if (rating != null)
                                    Text(
                                      '⭐ $rating'
                                      '${reviews != null ? ' ($reviews reviews)' : ''}',
                                      style: AppTextStyles.of(context).caption,
                                    ),

                                  if (hotelClass != null)
                                    Text(
                                      '$hotelClass-star hotel',
                                      style: AppTextStyles.of(context).caption.copyWith(
                                        color: AppColors.of(context).textMuted,
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
                                  color: AppColors.of(context).accentStart
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  price.toString(),
                                  style: AppTextStyles.of(context).button.copyWith(
                                    color: AppColors.of(context).accentEnd,
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
