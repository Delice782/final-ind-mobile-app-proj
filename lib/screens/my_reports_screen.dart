import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_helper.dart';
import 'package:audioplayers/audioplayers.dart';
import 'photo_viewer_screen.dart';
import 'edit_report_screen.dart';

const Color primaryColor = Color(0xFF8B1F1F); // Main red
const Color ashesiGold = Color(0xFFD4AF37);   // Success / “in progress”

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;

  // final String baseUrl = 'http://10.255.249.239/datasphere';
  // final String baseUrl = 'http://169.239.251.102/~delice.ishimwe/datasphere';
  // final String baseUrl = 'http://169.239.251.102:280/~delice.ishimwe/datasphere';
  final String baseUrl = 'http://169.239.251.102:280/~delice.ishimwe/datasphere';

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    // Try to sync any pending offline reports first
    await _syncOfflineReports();

    // load local unsynced reports
    final localReports = await DatabaseHelper.instance.getAllLocalReports(userId!);
    final unsyncedFormatted = localReports
        .where((r) => r['synced'] == 0)
        .map((r) => {
      'id': 'offline_${r['id']}',
      'building': r['building'],
      'room': r['room'] ?? '',
      'category': r['category'],
      'description': r['description'],
      'photo': r['photo'] ?? '',
      'audio': r['audio'] ?? '',
      'status': 'Pending',
      'created_at': r['created_at'] ?? '',
      'user_name': 'You (offline)',
      'is_offline': true,
    })
        .toList();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_my_reports.php?user_id=$userId'),
      );
      final data = jsonDecode(response.body);

      if (data['success']) {
        final serverReports = List<Map<String, dynamic>>.from(data['reports']);
        setState(() {
          _reports = [...unsyncedFormatted, ...serverReports];
        });
      }
    } catch (e) {
      setState(() => _reports = unsyncedFormatted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Showing offline reports'), backgroundColor: primaryColor),
      );
    }

    setState(() => _isLoading = false);
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
        return Colors.orange;
      case 'in progress':
        return ashesiGold;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
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
      final id = report['id'].toString();

      if (id.startsWith('offline_')) {
        // Delete from local SQLite — no server call needed
        final localId = int.parse(id.replaceFirst('offline_', ''));
        final db = await DatabaseHelper.instance.database;
        await db.delete('offline_reports', where: 'id = ?', whereArgs: [localId]);
        _fetchReports();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted'), backgroundColor: Colors.green),
        );
      } else {
        await _deleteReport(int.parse(id));
      }
    }
  }

  Future<void> _deleteReport(int reportId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final response = await http.post(
        Uri.parse('$baseUrl/delete_report.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'report_id': reportId,
          'user_id': userId,
          'is_admin': false,
        }),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted'), backgroundColor: Colors.green),
        );
        _fetchReports(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _syncOfflineReports() async {
    final unsyncedReports = await DatabaseHelper.instance.getUnsyncedReports();

    for (var report in unsyncedReports) {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/submit_report.php'),
        );

        request.fields['user_id'] = report['user_id'].toString();
        request.fields['building'] = report['building'];
        request.fields['room'] = report['room'] ?? '';
        request.fields['category'] = report['category'];
        request.fields['description'] = report['description'];

        if (report['audio'] != null && report['audio'] != '') {
          final cleanPath = report['audio'].toString().replaceFirst('file://', '');
          if (await File(cleanPath).exists()) {
            request.files.add(await http.MultipartFile.fromPath('audio', cleanPath));
          }
        }

        if (report['photo'] != null && report['photo'] != '') {
          if (await File(report['photo']).exists()) {
            request.files.add(await http.MultipartFile.fromPath('photo', report['photo']));
          }
        }

        var response = await request.send();
        if (response.statusCode == 200) {
          await DatabaseHelper.instance.markAsSynced(report['id']);
        }
      } catch (e) {
        // No internet yet, will retry next time
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B1F1F),
        foregroundColor: Colors.white,
        title: const Text('My Reports'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No reports yet',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchReports,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _reports.length,
          itemBuilder: (context, index) {
            final report = _reports[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(report['category'],
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('Report #${report['id']}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        _StatusBadge(status: report['status']),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 0.5),

                  // ── Building & Room
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _LabeledField(label: 'Building', value: report['building'] ?? ''),
                  ),

                  const Divider(height: 1, thickness: 0.5),

                  // ── Description
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _LabeledField(
                      label: 'Description',
                      value: report['description'] ?? '',
                      maxLines: 4,
                    ),
                  ),

                  // ── Photo
                  if (report['photo'] != null && report['photo'].toString().isNotEmpty) ...[
                    const Divider(height: 1, thickness: 0.5),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('Photo'),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              if (!report['photo'].toString().startsWith('/')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhotoViewerScreen(
                                      imageUrl: '$baseUrl/uploads/${report['photo']}',
                                      title: 'Report Photo',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: report['photo'].toString().startsWith('/')
                                  ? Image.file(File(report['photo']),
                                  height: 150, width: double.infinity, fit: BoxFit.cover)
                                  : Image.network(
                                '$baseUrl/uploads/${report['photo']}',
                                height: 150, width: double.infinity, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 150,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Voice Note
                  if (report['audio'] != null && report['audio'].toString().isNotEmpty) ...[
                    const Divider(height: 1, thickness: 0.5),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('Voice Note'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mic, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text('Voice note attached',
                                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final audio = report['audio']?.toString() ?? '';
                                    if (audio.isEmpty) return;
                                    final url = audio.startsWith('/')
                                        ? audio
                                        : '$baseUrl/uploads/$audio';
                                    if (_isPlaying && _currentlyPlaying == url) {
                                      await _audioPlayer.stop();
                                      setState(() { _isPlaying = false; _currentlyPlaying = null; });
                                    } else {
                                      if (audio.startsWith('/')) {
                                        await _audioPlayer.play(DeviceFileSource(audio));
                                      } else {
                                        await _audioPlayer.play(UrlSource(url));
                                      }
                                      setState(() { _isPlaying = true; _currentlyPlaying = url; });
                                      _audioPlayer.onPlayerComplete.listen((_) {
                                        setState(() { _isPlaying = false; _currentlyPlaying = null; });
                                      });
                                    }
                                  },
                                  child: Icon(
                                    _isPlaying && _currentlyPlaying == (
                                        report['audio'].toString().startsWith('/')
                                            ? report['audio'].toString()
                                            : '$baseUrl/uploads/${report['audio']}')
                                        ? Icons.stop_circle
                                        : Icons.play_circle,
                                    color: primaryColor,
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

                  // ── GPS
                  if (report['latitude'] != null && report['latitude'].toString().isNotEmpty) ...[
                    const Divider(height: 1, thickness: 0.5),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: _LabeledField(
                        label: 'GPS Location',
                        value: '${report['latitude']}, ${report['longitude']}',
                      ),
                    ),
                  ],

                  const Divider(height: 1, thickness: 0.5),

                  // ── Timestamp
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Text(_formatDate(report['created_at']),
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),

                  // ── Edit / Delete (pending only)
                  if (report['status'] == 'Pending') ...[
                    const Divider(height: 1, thickness: 0.5),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getInt('user_id');
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditReportScreen(
                                      report: report, userId: userId!),
                                ),
                              );
                              if (result == true) _fetchReports();
                            },
                            icon: const Icon(Icons.edit, size: 15),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _confirmDelete(report),
                            icon: const Icon(Icons.delete, size: 15),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    const SizedBox(height: 8),

                  // ── Resolution Notes (resolved only)
                  if (report['status'] == 'Resolved' && report['resolution_notes'] != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF3DE),
                        border: Border(left: BorderSide(color: Colors.green, width: 3)),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('Resolution Notes'),
                          const SizedBox(height: 4),
                          Text(report['resolution_notes'],
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
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

class _LabeledField extends StatelessWidget {
  final String label, value;
  final int maxLines;
  const _LabeledField(
      {required this.label, required this.value, this.maxLines = 2});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(label),
      const SizedBox(height: 4),
      Text(value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}