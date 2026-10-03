import 'dart:async';
import 'package:flutter/material.dart';
import '../services/airport_service.dart';
import '../theme/app_theme.dart';

class AirportSearchField extends StatefulWidget {
  const AirportSearchField({
    super.key,
    required this.controller,
    required this.label,
    required this.onSelected,
    this.service,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<Airport?> onSelected;
  final AirportService? service;

  @override
  State<AirportSearchField> createState() => _AirportSearchFieldState();
}

class _AirportSearchFieldState extends State<AirportSearchField> {
  late final AirportService _service = widget.service ?? AirportService();
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false;
  String? _message;
  AirportSuggestions? _suggestions;

  void _changed(String value) {
    widget.onSelected(null);
    _debounce?.cancel();
    final generation = ++_generation;
    final query = value.trim();
    setState(() {
      _suggestions = null;
      _message = null;
      _loading = query.length >= 2;
    });
    if (query.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await _service.search(query);
        if (!mounted || generation != _generation) return;
        setState(() {
          _loading = false;
          _suggestions = result;
          if (result.airports.isEmpty) {
            _message =
                'No matching airport with a confirmed code. Try its name or IATA code.';
          }
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _loading = false;
          _message =
              'Suggestions unavailable. Try again or enter an IATA code.';
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _changed,
          style: AppTextStyles.body,
          maxLength: 120,
          decoration:
              AppDecorations.inputDecoration(
                label: widget.label,
                prefixIcon: Icons.flight,
                suffixIcon: Icons.search,
              ).copyWith(
                counterText: '',
                helperText:
                    'Search a city, airport name, or IATA code; select a result.',
                helperMaxLines: 2,
              ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message!),
          ),
        if (_suggestions != null) ...[
          for (final airport in _suggestions!.airports)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(airport.label),
              subtitle: Text(
                [airport.address, ...airport.attributions].join('\n'),
              ),
              onTap: () {
                _debounce?.cancel();
                ++_generation;
                widget.controller.text = airport.label;
                widget.onSelected(airport);
                setState(() {
                  _suggestions = null;
                  _message = null;
                  _loading = false;
                });
                FocusScope.of(context).unfocus();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _suggestions!.source,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
