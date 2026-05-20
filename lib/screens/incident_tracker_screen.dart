import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:khabar/api_config.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khabar/theme/app_colors.dart';

class IncidentTrackerScreen extends StatefulWidget {
  final Map<String, dynamic>? incidentData;
  const IncidentTrackerScreen({super.key, this.incidentData});

  @override
  State<IncidentTrackerScreen> createState() => _IncidentTrackerScreenState();
}

class _IncidentTrackerScreenState extends State<IncidentTrackerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkAnimationController;
  late Animation<double> _checkAnimation;

  Map<String, dynamic>? _liveIncidentData;
  bool _isLoadingIncident = false;
  String? _errorMessage;
  bool _isHelpDelivered = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkAnimationController,
      curve: Curves.elasticOut,
    );
    _checkAnimationController.forward();
    
    if (widget.incidentData != null) {
      _liveIncidentData = widget.incidentData;
    }
    
    _fetchLatestIncident();
    
    // Start polling every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_liveIncidentData != null) {
        final status = _liveIncidentData!['status'];
        if (status != 'COMPLETED' && status != 'RESOLVED') {
          _pollSpecificIncident(_liveIncidentData!['incident_id']);
        } else {
          timer.cancel(); // Stop polling once completed
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _checkAnimationController.dispose();
    super.dispose();
  }

  Future<void> _pollSpecificIncident(String incidentId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/incident/$incidentId'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _liveIncidentData = data;
          });
        }
      }
    } catch (e) {
      // Ignore polling errors to not interrupt the UI aggressively
    }
  }

  Future<void> _fetchLatestIncident() async {
    if (_liveIncidentData != null) return; // Only fetch if we didn't receive one from constructor
    if (!mounted) return;
    setState(() {
      _isLoadingIncident = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/incidents'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List incidents = data['incidents'] ?? [];
        if (mounted) {
          setState(() {
            if (incidents.isNotEmpty) {
              _liveIncidentData = incidents.first; // Latest active incident
            } else {
              _liveIncidentData = null;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Server returned error: ${response.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Connection error. Make sure the backend server is running.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingIncident = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _effectiveData => _liveIncidentData ?? widget.incidentData;

  String get _incidentId {
    final data = _effectiveData;
    if (data == null) {
      return _isLoadingIncident ? 'Loading...' : 'No Incident';
    }
    final raw = data['incident_id']?.toString() ?? 'KHABAR-0001';
    return raw.length > 14 ? '${raw.substring(0, 14)}…' : raw;
  }

  String get _status {
    final data = _effectiveData;
    if (data == null) {
      return _isLoadingIncident ? 'Checking dispatcher...' : 'No Active Dispatches';
    }
    return data['status']?.toString() ?? 'Processing...';
  }

  String get _priority {
    final data = _effectiveData;
    if (data == null) return 'P—';
    return data['priority']?.toString() ?? 'P1';
  }

  @override
  Widget build(BuildContext context) {
    final data = _effectiveData;

    return Scaffold(
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        title: const Text('Incident Status',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kBackgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchLatestIncident,
          color: kPrimaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              children: [
                if (_isLoadingIncident)
                  _buildLoadingState()
                else if (data == null)
                  _buildNoActiveDispatchesState()
                else ...[
                  // ── 1. Animated Checkmark ──
                  ScaleTransition(
                    scale: _checkAnimation,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: kPrimaryTeal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: kPrimaryTeal, size: 60),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 2. Incident ID + Priority Badge ──
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        _incidentId,
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryTeal,
                        ),
                      ),
                      Positioned(
                        top: -6, right: -36,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kEmergencyRed, borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_priority,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── 3. Status ──
                  Text(_status, style: const TextStyle(color: kTextLight, fontSize: 14)),
                  const SizedBox(height: 24),

                  // ── 3b. Animated Pipeline Header (FR-Animation) ──
                  _buildAnimatedPipelineHeader(),
                  const SizedBox(height: 24),

                  // ── 4. Agent Timeline ──
                  if (data['traces'] != null)
                    ..._buildRealTraces(data['traces'] as List),

                  // ── 5. Before / After State (FR-23) ──
                  if (data['before_state'] != null &&
                      data['after_state'] != null)
                    _buildBeforeAfterPanel(
                      data['before_state'] as Map<String, dynamic>,
                      data['after_state'] as Map<String, dynamic>,
                      data['state_diff'] as Map<String, dynamic>?,
                    ),
                    
                  // ── 6. Resource Dispatch Confirmation ──
                  if (data['status'] == 'COMPLETED' || _status.toLowerCase().contains("complete"))
                    _buildDispatchDetailsPanel(data),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dispatch Details Panel ──
  Widget _buildDispatchDetailsPanel(Map<String, dynamic> data) {
    // Extract resource info from after_state or active_units
    String resourceName = 'Emergency Response Unit';
    String distance = '2.4 km';
    String eta = '6 Minutes';

    final afterState = data['after_state'] as Map<String, dynamic>?;
    if (afterState != null) {
      final units = afterState['active_units'] as Map?;
      if (units != null && units.isNotEmpty) {
        resourceName = units.values.first['type']?.toString() ?? resourceName;
        // Mock distance/eta if not in backend yet
        distance = '1.8 km';
        eta = '4 Minutes';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Card(
        elevation: 2.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _isHelpDelivered ? Colors.green.withValues(alpha: 0.3) : kPrimaryTeal.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        color: _isHelpDelivered ? Colors.green.withValues(alpha: 0.05) : kCardWhite,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_isHelpDelivered ? Icons.verified : Icons.local_shipping, 
                       color: _isHelpDelivered ? Colors.green : kPrimaryTeal, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _isHelpDelivered ? 'Help Delivered' : 'Dispatch En Route',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isHelpDelivered ? Colors.green : kTextDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isHelpDelivered) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Resource:', style: GoogleFonts.nunito(fontSize: 14, color: kTextLight)),
                    Text(resourceName, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Distance:', style: GoogleFonts.nunito(fontSize: 14, color: kTextLight)),
                    Text(distance, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Expected Arrival:', style: GoogleFonts.nunito(fontSize: 14, color: kTextLight)),
                    Text(eta, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: kEmergencyRed)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isHelpDelivered = true;
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirm Help Delivered'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'You have confirmed that the emergency resource has arrived and help was delivered safely.',
                  style: GoogleFonts.nunito(fontSize: 14, color: kTextDark),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: kPrimaryTeal),
            const SizedBox(height: 16),
            Text(
              'Checking active dispatcher pipeline...',
              style: GoogleFonts.nunito(fontSize: 14, color: kTextLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveDispatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: kPrimaryTeal.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No Active Dispatches Found',
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'No emergency signals have been reported or require active routing at this time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13, color: kTextLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchLatestIncident,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Before / After Panel ──
  Widget _buildBeforeAfterPanel(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    Map<String, dynamic>? diff,
  ) {
    final changedKeys = (diff?['changed_keys'] as List?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: kCardWhite,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.compare_arrows, color: kPrimaryTeal, size: 20),
                  const SizedBox(width: 8),
                  Text('Before → After State',
                      style: GoogleFonts.nunito(
                          fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('✅ Simulation Complete',
                        style: GoogleFonts.nunito(
                            fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Before
                  Expanded(child: _buildStateBox('BEFORE', before, changedKeys, false)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                    child: Icon(Icons.arrow_forward, color: kPrimaryTeal, size: 28),
                  ),
                  // After
                  Expanded(child: _buildStateBox('AFTER', after, changedKeys, true)),
                ],
              ),
              if (_effectiveData?['generated_alerts'] != null && (_effectiveData!['generated_alerts'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('Public Alerts Generated:',
                        style: GoogleFonts.nunito(
                            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    (_effectiveData!['generated_alerts'] as List).first.toString(),
                    style: GoogleFonts.nunito(fontSize: 12, color: kTextDark),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateBox(
    String label,
    Map<String, dynamic> state,
    List<String> changedKeys,
    bool isAfter,
  ) {
    final rows = <Map<String, String>>[
      {'key': 'Status', 'val': state['status']?.toString() ?? '—'},
      {'key': 'Active Units', 'val': (state['active_units'] as Map?)?.length.toString() ?? '0'},
      {'key': 'Alerts Sent', 'val': state['public_alerts_sent']?.toString() ?? '0'},
      {'key': 'Roads Closed', 'val': (state['closed_roads'] as List?)?.length.toString() ?? '0'},
      {'key': 'Tickets', 'val': (state['tickets'] as List?)?.length.toString() ?? '0'},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAfter
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAfter
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isAfter ? Colors.green : kTextLight,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) {
            final isChanged = isAfter && changedKeys.contains(
              r['key']!.toLowerCase().replaceAll(' ', '_'),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r['key']!,
                      style: GoogleFonts.nunito(fontSize: 11, color: kTextLight)),
                  Text(
                    r['val']!,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isChanged ? Colors.green : kTextDark,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Real Traces from API ──
  List<Widget> _buildRealTraces(List traces) {
    final widgets = <Widget>[];
    for (int i = 0; i < traces.length; i++) {
      final trace = traces[i].toString();
      String phase = 'SYSTEM';
      String msg = trace;
      final match = RegExp(r'\[(.*?)\] \[(.*?)\] (.*)').firstMatch(trace);
      if (match != null) {
        phase = match.group(2) ?? 'SYSTEM';
        msg = match.group(3) ?? trace;
      }
      final color = _phaseColor(phase);
      widgets.add(_buildTimelineStep(
        isFirst: i == 0,
        isLast: i == traces.length - 1,
        color: color,
        agentName: phase,
        content: Text(
          msg,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: kTextDark,
          ),
        ),
      ));
    }
    return widgets;
  }

  Color _phaseColor(String phase) {
    switch (phase) {
      case 'DETECTION': return Colors.blue.shade400;
      case 'ANALYSIS': return Colors.purple.shade400;
      case 'PLANNING': return Colors.teal.shade400;
      case 'EXECUTION': return kPrimaryTeal;
      case 'PIPELINE_COMPLETE': return Colors.green;
      case 'FALLBACK': return kEmergencyRed;
      default: return Colors.grey.shade400;
    }
  }

  // ── Timeline Step Widget ──
  Widget _buildTimelineStep({
    required bool isFirst,
    required bool isLast,
    required Color color,
    required String agentName,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(width: 2, height: 16,
                      color: isFirst ? Colors.transparent : kPrimaryTeal.withValues(alpha: 0.3)),
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                  ),
                  Expanded(child: Container(width: 2,
                      color: isLast ? Colors.transparent : kPrimaryTeal.withValues(alpha: 0.3))),
                ],
              ),
            ),
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: kCardWhite,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agentName,
                          style: GoogleFonts.nunito(
                              fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(height: 8),
                      content,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Animated Pipeline Header ──
  Widget _buildAnimatedPipelineHeader() {
    String activePhase = "DETECTION"; // fallback
    final data = _effectiveData;
    bool isComplete = data?['status'] == "COMPLETED" || 
                       data?['status'] == "Pipeline Complete" ||
                       _status.toLowerCase().contains("complete");
                       
    final List<dynamic>? traces = data?['traces'];
    if (isComplete) {
      activePhase = "COMPLETED";
    } else if (traces != null && traces.isNotEmpty) {
      for (final trace in traces) {
        final lower = trace.toString().toLowerCase();
        if (lower.contains("execution")) {
          activePhase = "EXECUTION";
        } else if (lower.contains("planning")) {
          activePhase = "PLANNING";
        } else if (lower.contains("analysis")) {
          activePhase = "ANALYSIS";
        } else if (lower.contains("detection")) {
          activePhase = "DETECTION";
        }
      }
    }

    final List<Map<String, dynamic>> agents = [
      {"id": "DETECTION", "name": "Detection", "icon": Icons.radar},
      {"id": "ANALYSIS", "name": "Analysis", "icon": Icons.analytics_outlined},
      {"id": "PLANNING", "name": "Planning", "icon": Icons.tips_and_updates},
      {"id": "EXECUTION", "name": "Execution", "icon": Icons.bolt},
    ];

    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Multi-Agent AI Pipeline",
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isComplete 
                        ? Colors.green.withValues(alpha: 0.1) 
                        : kPrimaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      if (!isComplete)
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation(kPrimaryTeal),
                          ),
                        ),
                      if (!isComplete) const SizedBox(width: 6),
                      Text(
                        isComplete ? "COMPLETED" : "PROCESSING",
                        style: GoogleFonts.nunito(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isComplete ? Colors.green : kPrimaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(agents.length * 2 - 1, (index) {
                if (index.isOdd) {
                  final stepIndex = index ~/ 2;
                  bool isPassed = _isStepPassed(agents[stepIndex]['id'], activePhase);
                  return Expanded(
                    child: Container(
                      height: 3,
                      color: isPassed ? kPrimaryTeal : Colors.grey.shade200,
                    ),
                  );
                } else {
                  final stepIndex = index ~/ 2;
                  final agent = agents[stepIndex];
                  bool isActive = activePhase == agent['id'];
                  bool isPassed = _isStepPassed(agent['id'], activePhase);
                  
                  return _buildAgentBubble(agent, isActive, isPassed);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  bool _isStepPassed(String stepId, String activePhase) {
    if (activePhase == "COMPLETED") return true;
    final list = ["DETECTION", "ANALYSIS", "PLANNING", "EXECUTION"];
    final stepIdx = list.indexOf(stepId);
    final activeIdx = list.indexOf(activePhase);
    return stepIdx <= activeIdx;
  }

  Widget _buildAgentBubble(Map<String, dynamic> agent, bool isActive, bool isPassed) {
    Color bubbleColor = Colors.grey.shade100;
    Color iconColor = Colors.grey;
    if (isActive) {
      bubbleColor = kPrimaryTeal;
      iconColor = Colors.white;
    } else if (isPassed) {
      bubbleColor = kPrimaryTeal.withValues(alpha: 0.15);
      iconColor = kPrimaryTeal;
    }

    return Tooltip(
      message: agent['name'],
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            width: isActive ? 52 : 44,
            height: isActive ? 52 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bubbleColor,
              border: Border.all(
                color: isActive ? Colors.white : (isPassed ? kPrimaryTeal : Colors.transparent),
                width: 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: kPrimaryTeal.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              isPassed && !isActive ? Icons.check : agent['icon'],
              color: iconColor,
              size: isActive ? 26 : 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            agent['name'],
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? kPrimaryTeal : kTextLight,
            ),
          ),
        ],
      ),
    );
  }
}

