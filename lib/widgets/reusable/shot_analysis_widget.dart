// shot_analysis_widget.dart
import 'package:flutter/material.dart';

class ShotAnalysis {
  final String shotType;
  final double intensity;
  final List<String> suggestions;

  ShotAnalysis({
    required this.shotType,
    required this.intensity,
    required this.suggestions,
  });
}

class ShotAnalysisWidget extends StatefulWidget {
  final List<ShotAnalysis> shots;
  final Map<String, int> shotCounts;
  final Map<String, double> avgIntensity;

  const ShotAnalysisWidget({
    super.key,
    required this.shots,
    required this.shotCounts,
    required this.avgIntensity,
  });

  @override
  State<ShotAnalysisWidget> createState() => _ShotAnalysisWidgetState();
}

class _ShotAnalysisWidgetState extends State<ShotAnalysisWidget> {
  int? expandedShotIndex;

  Color _getIntensityColor(double intensity) {
    if (intensity >= 180) return Colors.red;
    if (intensity >= 160) return Colors.orange;
    if (intensity >= 140) return Colors.yellow[700]!;
    return Colors.green;
  }

  void _toggleShotExpansion(int index) {
    setState(() {
      expandedShotIndex = expandedShotIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "Shot Analysis (${widget.shots.length} shots)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            Divider(
              height: 20,
              thickness: 1,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),

            // Shot List with expandable rows
            if (widget.shots.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    "No shots analyzed yet",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.shots.length,
                itemBuilder: (context, index) {
                  final shot = widget.shots[widget.shots.length - 1 - index]; // Show newest first
                  final shotNumber = widget.shots.length - index;
                  final isExpanded = expandedShotIndex == index;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: Column(
                      children: [
                        // Shot Summary Row
                        InkWell(
                          onTap: () => _toggleShotExpansion(index),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Shot Number Badge
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      shotNumber.toString(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Shot Info - UPDATED SECTION
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            shot.shotType,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text("Intensity: ", style: TextStyle(fontSize: 14)),
                                              Text(
                                                (shot.intensity ?? 0.0).toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getIntensityColor(shot.intensity),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "${shot.suggestions.length} tips",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Expand/Collapse Icon
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded Suggestions Section
                        if (isExpanded)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb,
                                        size: 18,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Improvement Suggestions:",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...shot.suggestions.map((suggestion) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            suggestion,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
