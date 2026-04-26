import 'photo_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'profile_screen.dart';

const Color ashesiGold = Color(0xFFD4AF37);

class FacilitiesDashboardScreen extends StatefulWidget {
  const FacilitiesDashboardScreen({super.key});

  @override
  State<FacilitiesDashboardScreen> createState() =>
      _FacilitiesDashboardScreenState();
}

class _FacilitiesDashboardScreenState
    extends State<FacilitiesDashboardScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  String _filterStatus = 'All';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentlyPlaying;
  String _name = '';

  final String baseUrl =
      'http://169.239.251.102:280/~delice.ishimwe/datasphere';

  @override
  void initState() {
    super.initState();
    _loadName();
    _fetchReports();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _name = prefs.getString('name') ?? 'Facilities');
  }

  Future<void> _fetchReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_all_reports.php'),
      );
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() => _reports = data['reports']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load reports')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateStatus(
      int reportId, String newStatus, String? resolutionNotes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'report_id': reportId,
          'status': newStatus,
          'resolution_notes': resolutionNotes,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success']) {
        _fetchReports();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated!'),
            backgroundColor: ashesiGold,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update status')),
      );
    }
  }

  Future<void> _showResolutionDialog(int reportId, String status) async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Resolved'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Resolution Notes',
            hintText: 'Describe how the issue was resolved...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _updateStatus(reportId, status, result);
    }
  }

  Future<void> _confirmDeleteAdmin(int reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text(
            'Are you sure? This will permanently delete this report.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteReportAdmin(reportId);
    }
  }

  Future<void> _deleteReportAdmin(int reportId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_report.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'report_id': reportId,
          'is_admin': true,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success']) {
        _fetchReports();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Report deleted'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error deleting report'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour =
      dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $period';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ashesiGold;
      case 'in progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<dynamic> get _filteredReports {
    if (_filterStatus == 'All') return _reports;
    return _reports.where((r) => r['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _reports.where((r) => r['status'] == 'Pending').length;
    final inProgress =
        _reports.where((r) => r['status'] == 'In Progress').length;
    final resolved =
        _reports.where((r) => r['status'] == 'Resolved').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DataSphere',
                style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Hello, $_name',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileScreen()),
              );
              _loadName();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STATS
              Row(
                children: [
                  _buildStatCard('Pending', pending, ashesiGold),
                  const SizedBox(width: 8),
                  _buildStatCard(
                      'In Progress', inProgress, Colors.blue),
                  const SizedBox(width: 8),
                  _buildStatCard(
                      'Resolved', resolved, Colors.green),
                ],
              ),

              const SizedBox(height: 20),

              const Text('Filter by Status',
                  style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 8),

              // FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    'Pending',
                    'In Progress',
                    'Resolved'
                  ]
                      .map((status) => Padding(
                    padding:
                    const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status),
                      selected: _filterStatus == status,
                      onSelected: (_) => setState(
                              () => _filterStatus = status),
                      selectedColor:
                      const Color(0xFF1A73E8)
                          .withOpacity(0.2),
                    ),
                  ))
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),

              const Text('All Reports',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),

              const SizedBox(height: 12),

              // REPORT CARDS
              ..._filteredReports.map((report) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 12),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(report['category'],
                                    style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w600,
                                        fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(
                                    'Report #${report['id']}',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          _FacilityStatusBadge(
                              status: report['status']),
                        ],
                      ),
                    ),

                    const Divider(height: 1, thickness: 0.5),

                    // Location
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 12, 16, 12),
                      child: _FacilityLabeledField(
                        label: 'Location',
                        value:
                        '${report['building']} - ${report['room']}',
                      ),
                    ),

                    const Divider(height: 1, thickness: 0.5),

                    // Reported By
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 12, 16, 12),
                      child: _FacilityLabeledField(
                        label: 'Reported By',
                        value:
                        report['user_name'] ?? 'Unknown',
                      ),
                    ),

                    const Divider(height: 1, thickness: 0.5),

                    // Description
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 12, 16, 12),
                      child: _FacilityLabeledField(
                        label: 'Description',
                        value: report['description'] ?? '',
                        maxLines: 4,
                      ),
                    ),

                    // Photo
                    if (report['photo'] != null &&
                        report['photo']
                            .toString()
                            .isNotEmpty) ...[
                      const Divider(
                          height: 1, thickness: 0.5),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const _FacilitySectionLabel(
                                'Photo'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PhotoViewerScreen(
                                        imageUrl:
                                        '$baseUrl/uploads/${report['photo']}',
                                        title: 'Report Photo',
                                      ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius:
                                BorderRadius.circular(8),
                                child: Image.network(
                                  '$baseUrl/uploads/${report['photo']}',
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context,
                                      error, stackTrace) =>
                                      Container(
                                        height: 150,
                                        color:
                                        Colors.grey.shade200,
                                        child: const Center(
                                            child: Icon(
                                                Icons.broken_image,
                                                color:
                                                Colors.grey)),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Voice Note
                    if (report['audio'] != null &&
                        report['audio']
                            .toString()
                            .isNotEmpty) ...[
                      const Divider(
                          height: 1, thickness: 0.5),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const _FacilitySectionLabel(
                                'Voice Note'),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mic,
                                      size: 16,
                                      color: Colors.grey),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                        'Voice note attached',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color:
                                            Colors.grey)),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final url =
                                          '$baseUrl/uploads/${report['audio']}';
                                      if (_isPlaying &&
                                          _currentlyPlaying ==
                                              url) {
                                        await _audioPlayer
                                            .stop();
                                        setState(() {
                                          _isPlaying = false;
                                          _currentlyPlaying =
                                          null;
                                        });
                                      } else {
                                        await _audioPlayer
                                            .play(
                                            UrlSource(url));
                                        setState(() {
                                          _isPlaying = true;
                                          _currentlyPlaying =
                                              url;
                                        });
                                        _audioPlayer
                                            .onPlayerComplete
                                            .listen((_) {
                                          setState(() {
                                            _isPlaying = false;
                                            _currentlyPlaying =
                                            null;
                                          });
                                        });
                                      }
                                    },
                                    child: Icon(
                                      _isPlaying &&
                                          _currentlyPlaying ==
                                              '$baseUrl/uploads/${report['audio']}'
                                          ? Icons.stop_circle
                                          : Icons.play_circle,
                                      color: const Color(
                                          0xFF8B1F1F),
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // GPS
                    if (report['latitude'] != null &&
                        report['latitude']
                            .toString()
                            .isNotEmpty) ...[
                      const Divider(
                          height: 1, thickness: 0.5),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 12),
                        child: _FacilityLabeledField(
                          label: 'GPS Location',
                          value:
                          '${report['latitude']}, ${report['longitude']}',
                        ),
                      ),
                    ],

                    const Divider(height: 1, thickness: 0.5),

                    // Timestamp
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 10, 16, 10),
                      child: Text(
                        _formatDate(report['created_at']),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ),

                    const Divider(height: 1, thickness: 0.5),

                    // Update Status
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 12, 16, 4),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const _FacilitySectionLabel(
                              'Update Status'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              'Pending',
                              'In Progress',
                              'Resolved'
                            ]
                                .map((status) => Padding(
                              padding:
                              const EdgeInsets.only(
                                  right: 6),
                              child: GestureDetector(
                                onTap: () {
                                  if (status ==
                                      'Resolved') {
                                    _showResolutionDialog(
                                        report['id'],
                                        status);
                                  } else {
                                    _updateStatus(
                                        report['id'],
                                        status,
                                        null);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 10,
                                      vertical: 6),
                                  decoration:
                                  BoxDecoration(
                                    color: report[
                                    'status'] ==
                                        status
                                        ? _getStatusColor(
                                        status)
                                        : Colors.grey
                                        .shade200,
                                    borderRadius:
                                    BorderRadius
                                        .circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                      FontWeight.bold,
                                      color: report[
                                      'status'] ==
                                          status
                                          ? Colors.white
                                          : Colors.grey
                                          .shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Delete
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _confirmDeleteAdmin(report['id']),
                          icon: const Icon(Icons.delete,
                              size: 15),
                          label:
                          const Text('Delete Report'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(
                                color: Colors.red),
                          ),
                        ),
                      ),
                    ),

                    // Resolution Notes
                    if (report['status'] == 'Resolved' &&
                        report['resolution_notes'] != null &&
                        report['resolution_notes']
                            .toString()
                            .isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF3DE),
                          border: Border(
                              left: BorderSide(
                                  color: Colors.green,
                                  width: 3)),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const _FacilitySectionLabel(
                                'Resolution Notes'),
                            const SizedBox(height: 4),
                            Text(
                                report['resolution_notes']
                                    .toString(),
                                style: const TextStyle(
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _FacilitySectionLabel extends StatelessWidget {
  final String text;
  const _FacilitySectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
        letterSpacing: 0.6),
  );
}

class _FacilityLabeledField extends StatelessWidget {
  final String label, value;
  final int maxLines;
  const _FacilityLabeledField(
      {required this.label, required this.value, this.maxLines = 2});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FacilitySectionLabel(label),
      const SizedBox(height: 4),
      Text(value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style:
          const TextStyle(fontSize: 13, color: Colors.black87)),
    ],
  );
}

class _FacilityStatusBadge extends StatelessWidget {
  final String status;
  const _FacilityStatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'resolved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'in progress':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
    }
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}