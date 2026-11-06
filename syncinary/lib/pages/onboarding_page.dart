import 'package:flutter/material.dart';

import '../services/group_service.dart';
import '../theme/app_theme.dart';
import 'groups/my_groups_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.groupService});

  /// Passed to the groups landing page when onboarding finishes.
  final GroupService? groupService;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _slideCount = 3;
  int _currentSlide = 0;

  void _next() {
    if (_currentSlide < _slideCount - 1) {
      setState(() => _currentSlide++);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MyGroupsPage(service: widget.groupService),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.of(context).backgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey(_currentSlide),
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: AppDecorations.glassCard(context),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 80,
                                color: AppColors.of(context).accentEnd,
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Onboarding ${_currentSlide + 1}',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.of(context).headline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Placeholder text for this onboarding screen. '
                                'More content will be added here soon.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.of(context).body,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Semantics(
                        label: 'Slide ${_currentSlide + 1} of $_slideCount',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _slideCount,
                            (index) => Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == _currentSlide
                                    ? AppColors.of(context).accentEnd
                                    : AppColors.of(context).border,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            tooltip: 'Previous slide',
                            onPressed: _currentSlide == 0
                                ? null
                                : () => setState(() => _currentSlide--),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          IconButton.filled(
                            tooltip: _currentSlide == _slideCount - 1
                                ? 'Go to main screen'
                                : 'Next slide',
                            onPressed: _next,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
