import 'photo_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'package:audioplayers/audioplayers.dart';

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

  final String baseUrl = 'http://10.255.249.239/datasphere';


  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();

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

  Future<void> _updateStatus(int reportId, String newStatus) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'report_id': reportId,
          'status': newStatus
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
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
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

    return _reports
        .where((r) => r['status'] == _filterStatus)
        .toList();
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
        title: const Text('Facilities Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
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

              /// STATS
              Row(
                children: [
                  _buildStatCard('Pending', pending, ashesiGold),
                  const SizedBox(width: 8),
                  _buildStatCard('In Progress', inProgress, Colors.blue),
                  const SizedBox(width: 8),
                  _buildStatCard('Resolved', resolved, Colors.green),
                ],
              ),

              const SizedBox(height: 20),

              /// FILTER TITLE
              const Text(
                'Filter by Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              /// FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Pending', 'In Progress', 'Resolved']
                      .map(
                        (status) => Padding(
                      padding:
                      const EdgeInsets.only(right: 8),

                      child: FilterChip(
                        label: Text(status),
                        selected: _filterStatus == status,

                        onSelected: (_) {
                          setState(() {
                            _filterStatus = status;
                          });
                        },

                        selectedColor: const Color(0xFF1A73E8)
                            .withOpacity(0.2),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'All Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              /// REPORT CARDS
              ..._filteredReports.map((report) => Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    /// TITLE + STATUS
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,

                      children: [

                        Text(
                          report['category'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4),

                          decoration: BoxDecoration(
                            color: _getStatusColor(
                                report['status'])
                                .withOpacity(0.1),

                            borderRadius:
                            BorderRadius.circular(20),
                          ),

                          child: Text(
                            report['status'],

                            style: TextStyle(
                              color: _getStatusColor(
                                  report['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 8),

                    /// BUILDING
                    Row(
                      children: [
                        const Icon(Icons.apartment,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${report['building']} - ${report['room']}',
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13),
                        )
                      ],
                    ),

                    const SizedBox(height: 4),

                    /// USER
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Reported by: ${report['user_name']}',
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13),
                        )
                      ],
                    ),

                    const SizedBox(height: 4),

                    /// DESCRIPTION
                    Text(
                      report['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),

                    if (report['latitude'] != null &&
                        report['latitude'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'GPS: ${report['latitude']}, ${report['longitude']}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    if (report['audio'] != null &&
                        report['audio'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            const Text('Voice note',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                final url = '$baseUrl/uploads/${report['audio']}';
                                if (_isPlaying && _currentlyPlaying == url) {
                                  await _audioPlayer.stop();
                                  setState(() { _isPlaying = false; _currentlyPlaying = null; });
                                } else {
                                  await _audioPlayer.play(UrlSource(url));
                                  setState(() { _isPlaying = true; _currentlyPlaying = url; });
                                  _audioPlayer.onPlayerComplete.listen((_) {
                                    setState(() { _isPlaying = false; _currentlyPlaying = null; });
                                  });
                                }
                              },
                              child: Icon(
                                _isPlaying && _currentlyPlaying == '$baseUrl/uploads/${report['audio']}'
                                    ? Icons.stop_circle
                                    : Icons.play_circle,
                                color: const Color(0xFF8B1F1F),
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(report['created_at']),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    const SizedBox(height: 8),

                    /// IMAGE
                    /// IMAGE
                    if (report['photo'] != null &&
                        report['photo']
                            .toString()
                            .isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhotoViewerScreen(
                                imageUrl: '$baseUrl/uploads/${report['photo']}',
                                title: 'Report Photo',
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius:
                          BorderRadius.circular(8),

                          child: Image.network(
                            '$baseUrl/uploads/${report['photo']}',
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,

                            errorBuilder:
                                (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                color: Colors.grey.shade200,

                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    if (report['photo'] != null &&
                        report['photo']
                            .toString()
                            .isNotEmpty)
                      const SizedBox(height: 8),

                    const SizedBox(height: 12),

                    /// STATUS UPDATE
                    const Text(
                      'Update Status:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

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
                          onTap: () =>
                              _updateStatus(
                                report['id'],
                                status,
                              ),

                          child: Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),

                            decoration: BoxDecoration(
                              color:
                              report['status'] ==
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
              ))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, int count, Color color) {
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

            Text(
              '$count',

              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}