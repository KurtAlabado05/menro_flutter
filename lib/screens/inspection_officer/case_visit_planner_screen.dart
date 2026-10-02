import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';

class CaseVisitPlannerScreen extends StatefulWidget {
  const CaseVisitPlannerScreen({super.key});

  @override
  State<CaseVisitPlannerScreen> createState() => _CaseVisitPlannerScreenState();
}

class _CaseVisitPlannerScreenState extends State<CaseVisitPlannerScreen> {
  final _mapController = MapController();
  static const _fallbackCenter = LatLng(14.9545, 120.8995);

  @override
  Widget build(BuildContext context) {
    final inspectorId = context.watch<AuthProvider>().user?.id;
    final applicationQueue = context.watch<InspectionProvider>().queue;
    if (inspectorId == null) {
      return const Scaffold(body: Center(child: Text('Sign in to plan inspection visits.')));
    }

    final cases = FirebaseFirestore.instance
        .collection('case_documentation')
        .where('inspectorId', isEqualTo: inspectorId)
        .snapshots(includeMetadataChanges: true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visit Planner'),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cases,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load visits: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final visits = <Map<String, dynamic>>[];
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final date = data['visitScheduledAt'];
            if (date != null) {
              visits.add({...data, 'visitScheduledAt': date, 'visitKind': 'Case follow-up'});
            }
          }
          for (final application in applicationQueue) {
            final raw = application.raw;
            final date = raw['inspectionDate'] ??
                raw['inspectionScheduledDate'] ??
                raw['inspectionScheduledAt'];
            if (date == null) continue;
            visits.add({
              'title': application.applicantName.isEmpty
                  ? 'Permit inspection'
                  : application.applicantName,
              'siteAddress': application.locationOfTrees.isNotEmpty
                  ? application.locationOfTrees
                  : application.applicationAddress,
              'latitude': raw['treeLatitude'] ?? raw['latitude'],
              'longitude': raw['treeLongitude'] ?? raw['longitude'],
              'visitScheduledAt': date,
              'visitKind': 'Permit inspection',
            });
          }
          visits.sort((a, b) => _date(a['visitScheduledAt']).compareTo(
                _date(b['visitScheduledAt']),
              ));
          final mappedVisits = visits.where((data) {
            return data['latitude'] is num && data['longitude'] is num;
          }).toList();
          final points = mappedVisits
              .map((data) => LatLng(
                    (data['latitude'] as num).toDouble(),
                    (data['longitude'] as num).toDouble(),
                  ))
              .toList();
          final center = points.isEmpty ? _fallbackCenter : points.first;

          return Column(
            children: [
              if (snapshot.data!.metadata.isFromCache ||
                  snapshot.data!.metadata.hasPendingWrites)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    snapshot.data!.metadata.hasPendingWrites
                        ? 'Visit changes are waiting to sync.'
                        : 'Showing saved visits from this device.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                  ),
                ),
              SizedBox(
                height: 300,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: center,
                    zoom: points.isEmpty ? 12 : 14,
                    minZoom: 5,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'cenro_application',
                    ),
                    if (points.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            strokeWidth: 3,
                            color: AppColors.accentTeal,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (var index = 0; index < mappedVisits.length; index++)
                          Marker(
                            point: points[index],
                            width: 38,
                            height: 38,
                            builder: (context) => CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Scheduled Visits', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text('${visits.length} planned'),
                  ],
                ),
              ),
              if (visits.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Schedule a visit from a case record to plan a route.'),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: visits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final data = visits[index];
                      final hasCoordinates = data['latitude'] is num && data['longitude'] is num;
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                            child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary)),
                          ),
                          title: Text((data['title'] ?? 'Inspection visit').toString()),
                          subtitle: Text(
                            '${_formatVisit(_date(data['visitScheduledAt']))}\n'
                            '${data['siteAddress'] ?? 'Site location not specified'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: hasCoordinates
                              ? const Icon(Icons.location_on_outlined, color: AppColors.primary)
                              : const Icon(Icons.location_off_outlined, color: AppColors.textGrey),
                          onTap: hasCoordinates
                              ? () => _mapController.move(
                                    LatLng(
                                      (data['latitude'] as num).toDouble(),
                                      (data['longitude'] as num).toDouble(),
                                    ),
                                    16,
                                  )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatVisit(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Time not set';
    final time = TimeOfDay.fromDateTime(date).formatFromDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} · $time';
  }
}

extension on TimeOfDay {
  String formatFromDate() {
    final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hour:$minuteText ${period.name.toUpperCase()}';
  }
}
