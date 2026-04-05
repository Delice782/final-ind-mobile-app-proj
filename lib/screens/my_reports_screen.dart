import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_helper.dart';
import 'package:audioplayers/audioplayers.dart';
import 'photo_viewer_screen.dart';

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

  final String baseUrl = 'http://10.255.249.239/datasphere';
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

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_my_reports.php?user_id=$userId'),
      );

      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() => _reports = data['reports']);
      }
    } catch (e) {
      // ✅ No internet - load from local database
      final localReports = await DatabaseHelper.instance.getAllLocalReports(userId!);

      List<Map<String, dynamic>> formattedReports = [];
      for (var r in localReports) {
        formattedReports.add({
          'id': r['id'].toString(),
          'building': r['building'],
          'room': r['room'],
          'category': r['category'],
          'description': r['description'],
          'photo': r['photo'],
          'status': r['status'] ?? 'Pending',
          'created_at': r['created_at'] ?? '',
          'user_name': 'You (offline)',
        });
      }

      setState(() {
        _reports = formattedReports;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Showing offline reports'),
          backgroundColor: primaryColor,
        ),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(report['category'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(report['status'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          report['status'],
                          style: TextStyle(
                              color: _getStatusColor(report['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.apartment,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${report['building']} - ${report['room']}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(report['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  // ✅ Show photo if it exists
                  if (report['photo'] != null && report['photo'].toString().isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        // Only open fullscreen for server photos (not offline photos)
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
                            ? Image.file(  // ✅ Local offline photo
                          File(report['photo']),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                            : Image.network(  // ✅ Server photo
                          '$baseUrl/uploads/${report['photo']}',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (report['photo'] != null && report['photo'].toString().isNotEmpty)
                    const SizedBox(height: 8),

                  if (report['latitude'] != null &&
                      report['latitude'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
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
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          const Text('Voice note',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              final url = 'http://10.255.249.239/datasphere/uploads/${report['audio']}';
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
                              _isPlaying && _currentlyPlaying == 'http://10.255.249.239/datasphere/uploads/${report['audio']}'
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
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(report['created_at']),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ],
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