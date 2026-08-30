import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class flight_search extends StatelessWidget {
  const flight_search({super.key, required this.title, required this.initialResults});

  final String title;
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
        title: Text(title, style: AppTextStyles.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: initialResults.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flight_outlined,
                        size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No flights found.',
                        style: AppTextStyles.subtitle
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                itemCount: initialResults.length,
                itemBuilder: (_, i) {
                  final offer = initialResults[i];
                  final flights = offer['flights'] as List<dynamic>;
                  final first = flights.first;
                  final dep = first['departure_airport']['id'];
                  final arr = flights.last['arrival_airport']['id'];
                  final time = first['departure_airport']['time'];
                  final price = offer['price'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: AppDecorations.glassCard(),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Route icon
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
                            // Flight details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$dep  →  $arr',
                                      style: AppTextStyles.title
                                          .copyWith(fontSize: 17)),
                                  const SizedBox(height: 4),
                                  Text('Departs $time',
                                      style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            // Price tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.accentStart.withValues(alpha: 0.15),
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
                  );
                },
              ),
      ),
    );
  }
}
