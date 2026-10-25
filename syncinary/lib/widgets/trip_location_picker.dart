import 'package:flutter/material.dart';
import '../models/trip_location.dart';
import '../services/place_service.dart';
import '../theme/app_theme.dart';

Future<TripLocation?> pickTripLocation(
  BuildContext context, {
  String initialQuery = '',
  PlaceService? service,
}) => showDialog<TripLocation>(
  context: context,
  builder: (_) => _PlacePicker(initialQuery: initialQuery, service: service),
);

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({required this.initialQuery, this.service});
  final String initialQuery;
  final PlaceService? service;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  late final _service = widget.service ?? PlaceService();
  List<TripLocation> _results = [];
  String? _message;
  bool _loading = false;
  int _request = 0;

  Future<void> _search() async {
    final query = _controller.text.trim();
    final request = ++_request;
    setState(() {
      _results = [];
      _loading = query.length >= 2;
      _message = _loading
          ? null
          : 'Enter a place name and city or a full address.';
    });
    if (!_loading) return;
    try {
      final results = await _service.search(query);
      if (!mounted || request != _request) return;
      setState(() {
        _results = results;
        _loading = false;
        _message = results.isEmpty
            ? 'No places found. Try adding the city or a full address.'
            : null;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _message =
            'Place search is unavailable. Please try again. You can also save the item without a location.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose map location'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 200,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Place name or address',
                hintText: 'e.g. Hilton Times Square, New York',
              ),
              onChanged: (_) => setState(() {
                ++_request;
                _loading = false;
                _results = [];
                _message = null;
              }),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Find location'),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!),
              ),
            for (final location in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.place_outlined,
                  color: AppColors.accentEnd,
                ),
                title: Text(location.name),
                subtitle: Text(
                  location.address.isEmpty
                      ? '${location.latitude}, ${location.longitude}'
                      : location.address,
                ),
                onTap: () => Navigator.pop(context, location),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

/// Optional location control shared by the add and edit item dialogs.
class TripLocationField extends StatelessWidget {
  const TripLocationField({
    super.key,
    required this.location,
    required this.onChanged,
    required this.query,
    this.service,
  });
  final TripLocation? location;
  final ValueChanged<TripLocation?> onChanged;
  final String Function() query;
  final PlaceService? service;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (location != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place, color: AppColors.accentEnd),
          title: Text(location!.name),
          subtitle: location!.address.isEmpty ? null : Text(location!.address),
          trailing: IconButton(
            tooltip: 'Remove map location',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close),
          ),
        ),
      TextButton.icon(
        onPressed: () async {
          final selected = await pickTripLocation(
            context,
            initialQuery: location?.name ?? query(),
            service: service,
          );
          if (context.mounted && selected != null) onChanged(selected);
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(
          location == null
              ? 'Add map location (optional)'
              : 'Change map location',
        ),
      ),
    ],
  );
}
