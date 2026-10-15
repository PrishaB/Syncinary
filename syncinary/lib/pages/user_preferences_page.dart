import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_preferences.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';

class UserPreferencesPage extends StatefulWidget {
  const UserPreferencesPage({super.key, this.service});

  final UserPreferencesService? service;

  @override
  State<UserPreferencesPage> createState() => _UserPreferencesPageState();
}

class _UserPreferencesPageState extends State<UserPreferencesPage> {
  late final UserPreferencesService _service =
      widget.service ?? UserPreferencesService();
  final _formKey = GlobalKey<FormState>();
  final _amountControllers = <String, TextEditingController>{
    for (final field in userPreferenceFields)
      if (field.input == PreferenceInput.amount)
        field.id: TextEditingController(),
  };
  Map<String, dynamic> _values = {};
  String? _loadedUserId;
  String? _loadError;
  String? _saveError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final uid = _service.currentUserId;
      final preferences = await _service.load();
      if (!mounted) return;
      if (_service.currentUserId != uid) {
        throw FirebaseAuthException(code: 'user-changed');
      }
      _loadedUserId = uid;
      _values = preferences.toMap();
      for (final entry in _amountControllers.entries) {
        entry.value.text = _values[entry.key]?.toString() ?? '';
      }
    } on FirebaseAuthException {
      if (mounted) {
        _loadError = 'Please sign in again to load your preferences.';
      }
    } catch (_) {
      if (mounted) {
        _loadError = 'Could not load your preferences. Please retry.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(
        () => _saveError = 'Check the highlighted fields before saving.',
      );
      return;
    }
    for (final entry in _amountControllers.entries) {
      final text = entry.value.text.trim();
      _values[entry.key] = text.isEmpty ? null : double.parse(text);
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _service.save(
        UserPreferences.fromMap(_values),
        expectedUserId: _loadedUserId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preferences saved.')));
    } on FirebaseAuthException {
      if (mounted) {
        _saveError = 'Your sign-in changed. Reopen this screen before saving.';
      }
    } catch (_) {
      if (mounted) {
        _saveError =
            'Could not save your preferences. Your edits are still here. '
            'Please try again.';
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Set Preferences'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _buildLoadError()
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GradientButton(onPressed: _load, label: 'Retry'),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Your travel preferences', style: AppTextStyles.headline),
                const SizedBox(height: 8),
                Text(
                  'These preferences are saved to your account and apply '
                  'across all your groups. You can change them anytime.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 24),
                for (final field in userPreferenceFields) _buildField(field),
                if (_saveError != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _saveError!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Align(
                  child: GradientButton(
                    key: const Key('save_preferences'),
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
                    label: 'Save Preferences',
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(PreferenceField field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.title, style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(field.description, style: AppTextStyles.body),
          const SizedBox(height: 16),
          _buildInput(field),
        ],
      ),
    );
  }

  Widget _buildInput(PreferenceField field) {
    switch (field.input) {
      case PreferenceInput.amount:
        return TextFormField(
          key: ValueKey('preference_${field.id}'),
          controller: _amountControllers[field.id],
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.body,
          decoration: AppDecorations.inputDecoration(label: field.amountLabel),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            final amount = double.tryParse(text);
            if (amount == null || !amount.isFinite || amount < 0) {
              return 'Enter a valid amount of 0 or more.';
            }
            return null;
          },
        );
      case PreferenceInput.multipleChoice:
        final selected = (_values[field.id] as List).cast<String>();
        // Retain saved choices if the catalog changes or another client added one.
        final options = {...field.options, ...selected};
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: _saving
                    ? null
                    : (checked) => setState(() {
                        _values[field.id] = checked
                            ? [...selected, option]
                            : selected.where((item) => item != option).toList();
                      }),
              ),
          ],
        );
      case PreferenceInput.singleChoice:
        final selected = _values[field.id] as String?;
        final options = {...field.options, ?selected};
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('No preference'),
              selected: selected == null,
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _values[field.id] = null),
            ),
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: selected == option,
                onSelected: _saving
                    ? null
                    : (checked) => setState(
                        () => _values[field.id] = checked ? option : null,
                      ),
              ),
          ],
        );
    }
  }
}
