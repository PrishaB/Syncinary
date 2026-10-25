import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/group.dart';
import '../models/schedule.dart';
import '../services/map_tile_client.dart';
import '../services/place_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/trip_location_picker.dart';

class TripMapPage extends StatefulWidget {
  const TripMapPage({
    super.key,
    required this.group,
    required this.service,
    this.placeService,
    this.tileProvider,
  });

  final Group group;
  final ScheduleService service;
  final PlaceService? placeService;

  /// Allows offline map rendering in widget tests.
  final TileProvider? tileProvider;

  @override
  State<TripMapPage> createState() => _TripMapPageState();
}

class _TripMapPageState extends State<TripMapPage> {
  late Stream<List<ScheduleItem>> _items = widget.service.itemsStream(
    widget.group.id,
  );
  String? _day;
  String? _selectedId;

  Future<void> _locate(ScheduleItem item) async {
    final location = await pickTripLocation(
      context,
      initialQuery: item.location?.name ?? item.title,
      service: widget.placeService,
    );
    if (!mounted || location == null) return;
    try {
      await widget.service.setItemLocation(widget.group.id, item.id, location);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the location. Please try again.'),
        ),
      );
    }
  }

  void _showStops(List<ScheduleItem> items) {
    setState(() => _selectedId = items.first.id);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .6,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final item in items)
                ListTile(
                  leading: Icon(_icon(item.type), color: _color(item.type)),
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      item.day,
                      if (item.location!.name != item.title)
                        item.location!.name,
                      if (item.location!.address.isNotEmpty)
                        item.location!.address,
                      if (item.details.isNotEmpty) item.details,
                    ].join('\n'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const GradientAppBar(title: 'Trip Map'),
    body: SafeArea(
      child: StreamBuilder<List<ScheduleItem>>(
        stream: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load the trip map.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _items = widget.service.itemsStream(widget.group.id);
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // The service supplies creation order; preserve that order within a day.
          final indexed = snapshot.data!.indexed.toList()
            ..sort((a, b) {
              final day = a.$2.day.compareTo(b.$2.day);
              return day == 0 ? a.$1.compareTo(b.$1) : day;
            });
          final all = indexed.map((entry) => entry.$2).toList();
          final days = all.map((item) => item.day).toSet().toList();
          final day = days.contains(_day) ? _day : null;
          final visible = all
              .where((item) => day == null || item.day == day)
              .toList();
          final mapped = visible
              .where((item) => item.location?.isValid ?? false)
              .toList();

          final stops = ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.group.name, style: AppTextStyles.title),
              const SizedBox(height: 6),
              Text(
                '${mapped.length} of ${visible.length} stops on map',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Text(
                  'Add hotels, activities, or flights in the planner to see your trip here.',
                ),
              if (mapped.length < visible.length)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Add locations to show the remaining stops on the map.',
                  ),
                ),
              for (final item in visible)
                Card(
                  key: ValueKey('stop-${item.id}'),
                  color: item.id == _selectedId ? AppColors.surfaceLight : null,
                  child: ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icon(item.type), color: _color(item.type)),
                        if (mapped.contains(item))
                          Text('${mapped.indexOf(item) + 1}'),
                      ],
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      [
                        item.day,
                        if (item.location != null && item.location!.isValid)
                          item.location!.address.isEmpty
                              ? item.location!.name
                              : item.location!.address
                        else
                          'Location needed',
                        if (item.details.isNotEmpty) item.details,
                      ].join('\n'),
                    ),
                    onTap: mapped.contains(item)
                        ? () => setState(() => _selectedId = item.id)
                        : () => _locate(item),
                    trailing: IconButton(
                      tooltip: item.location == null
                          ? 'Add location'
                          : 'Change location',
                      icon: const Icon(Icons.edit_location_alt_outlined),
                      onPressed: () => _locate(item),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Stops are ordered by day, then by when they were added. Lines connect stops, not driving directions.',
              ),
            ],
          );
          final map = mapped.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 56,
                          color: AppColors.accentEnd,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No locations to show yet',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _RouteMap(
                  items: mapped,
                  selectedId: _selectedId,
                  onSelect: _showStops,
                  tileProvider: widget.tileProvider,
                );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(day),
                  initialValue: day ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Show itinerary',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Entire trip'),
                    ),
                    for (final value in days)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() {
                    _day = value == '' ? null : value;
                    _selectedId = null;
                  }),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 760) {
                      return Row(
                        children: [
                          SizedBox(width: 320, child: stops),
                          Expanded(child: map),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(flex: 3, child: map),
                        Expanded(flex: 2, child: stops),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

IconData _icon(ScheduleItemType type) => switch (type) {
  ScheduleItemType.hotel => Icons.hotel_rounded,
  ScheduleItemType.flight => Icons.flight_rounded,
  ScheduleItemType.activity => Icons.local_activity_rounded,
};

Color _color(ScheduleItemType type) => switch (type) {
  ScheduleItemType.hotel => const Color(0xFF7552C8),
  ScheduleItemType.flight => const Color(0xFF1466A3),
  ScheduleItemType.activity => const Color(0xFF087F72),
};

LatLng _point(ScheduleItem item) =>
    LatLng(item.location!.latitude, item.location!.longitude);

class _RouteMap extends StatefulWidget {
  const _RouteMap({
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.tileProvider,
  });
  final List<ScheduleItem> items;
  final String? selectedId;
  final ValueChanged<List<ScheduleItem>> onSelect;
  final TileProvider? tileProvider;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  final _controller = MapController();
  MapTileClient? _tileClient;
  late final TileProvider _tileProvider;
  bool _tileError = false;
  int _tileGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.tileProvider == null) _tileClient = MapTileClient();
    _tileProvider =
        widget.tileProvider ?? NetworkTileProvider(httpClient: _tileClient);
  }

  CameraFit get _fit => CameraFit.coordinates(
    coordinates: widget.items.map(_point).toList(),
    padding: const EdgeInsets.all(56),
    maxZoom: 15,
  );

  String _geometry(List<ScheduleItem> items) => items
      .map(
        (item) =>
            '${item.id}:${item.location!.latitude},${item.location!.longitude}',
      )
      .join('|');

  @override
  void didUpdateWidget(covariant _RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_geometry(oldWidget.items) != _geometry(widget.items)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.fitCamera(_fit);
      });
    } else if (oldWidget.selectedId != widget.selectedId) {
      final selected = widget.items
          .where((item) => item.id == widget.selectedId)
          .firstOrNull;
      if (selected != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _controller.move(_point(selected), 15);
        });
      }
    }
  }

  @override
  void dispose() {
    // NetworkTileProvider leaves externally supplied clients to their owner.
    _tileClient?.close();
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double delta) => _controller.move(
    _controller.camera.center,
    (_controller.camera.zoom + delta).clamp(2.0, 19.0),
  );

  @override
  Widget build(BuildContext context) {
    final tileGeneration = _tileGeneration;
    // Shared locations get a single marker whose details include every stop.
    final groups = <LatLng, List<ScheduleItem>>{};
    for (final item in widget.items) {
      groups.putIfAbsent(_point(item), () => []).add(item);
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: _fit,
            minZoom: 2,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              key: ValueKey(_tileGeneration),
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.syncinary',
              maxNativeZoom: 19,
              tileProvider: _tileProvider,
              errorTileCallback: (_, error, stackTrace) {
                if (_tileError || tileGeneration != _tileGeneration) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted &&
                      !_tileError &&
                      tileGeneration == _tileGeneration) {
                    setState(() => _tileError = true);
                  }
                });
                WidgetsBinding.instance.ensureVisualUpdate();
              },
            ),
            PolylineLayer(
              polylines: [
                if (widget.items.length > 1)
                  Polyline(
                    points: widget.items.map(_point).toList(),
                    color: const Color(0xFF7552C8),
                    strokeWidth: 4,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final entry in groups.entries)
                  Marker(
                    point: entry.key,
                    width: 54,
                    height: 54,
                    child: Tooltip(
                      message: entry.value.map((item) => item.title).join(', '),
                      child: Material(
                        color: _color(entry.value.first.type),
                        shape: CircleBorder(
                          side: BorderSide(
                            color:
                                entry.value.any(
                                  (item) => item.id == widget.selectedId,
                                )
                                ? Colors.amber
                                : Colors.white,
                            width: 3,
                          ),
                        ),
                        elevation: 4,
                        child: InkWell(
                          key: ValueKey('marker-${entry.value.first.id}'),
                          customBorder: const CircleBorder(),
                          onTap: () => widget.onSelect(entry.value),
                          child: Semantics(
                            button: true,
                            label: entry.value
                                .map((item) => item.title)
                                .join(', '),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    entry.value.length > 1
                                        ? Icons.layers
                                        : _icon(entry.value.first.type),
                                    size: 21,
                                    color: Colors.white,
                                  ),
                                  Text(
                                    entry.value.length > 1
                                        ? '${entry.value.length} stops'
                                        : '${widget.items.indexOf(entry.value.first) + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () async {
                    try {
                      final opened = await launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      );
                      if (!opened) {
                        throw StateError('Could not open attribution');
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Map data © OpenStreetMap contributors: openstreetmap.org/copyright',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(color: Colors.black87, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: () => _zoom(1),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: () => _zoom(-1),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'Fit all stops',
                  onPressed: () => _controller.fitCamera(_fit),
                  icon: const Icon(Icons.fit_screen),
                ),
              ],
            ),
          ),
        ),
        if (_tileError)
          Positioned(
            left: 8,
            right: 72,
            top: 8,
            child: Material(
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Map tiles could not load. Your trip stops are still available.',
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _tileError = false;
                        ++_tileGeneration;
                      }),
                      child: const Text('Retry map'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
