import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../services/database_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

const Color ashesiGold = Color(0xFFFFD700); // Gold color for unified theme

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _descriptionController = TextEditingController();
  String? _selectedBuilding;
  String? _selectedCategory;
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  double? _latitude;
  double? _longitude;
  String _locationStatus = 'Tap to capture location';
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;
  String _recordStatus = 'Tap mic to record voice note';
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  // final String baseUrl = 'http://10.255.249.239/datasphere';
  // final String baseUrl = 'http://169.239.251.102/~delice.ishimwe/datasphere';
  // final String baseUrl = 'http://169.239.251.102:280/~delice.ishimwe/datasphere';
  final String baseUrl = 'http://169.239.251.102:280/~delice.ishimwe/datasphere';


  final List<String> buildings = [
    // Academic & Administrative
    'Radichel Hall',
    'Warren Library',
    'Apt Hall',
    'Jackson Hall',
    'Databank Foundation Hall',
    'Ashesi Bookshop',
    'King Engineering Building',
    'Nutor Hall',
    'Fabrication Lab (Fab Lab)',
    'Engineering Workshop',

    // Dining
    'The Hive',
    'The Grill',
    'Bliss Lounge',

    // Health & Sports
    'Natembea Health Centre',
    'Sports Centre',
    'Basketball / Volleyball Courts',
    'Isolation Wards',

    // Courtyards, Plazas & Lobbies
    'Archer Cornfield Courtyard',
    'Founders Plaza',
    'Collins Courtyard',
    'Porters Lodge (Student Dorms)',
    'Thacher Arboretum',

    // Student Residential Halls
    'Sutherland Hall',
    'Amu Hall',
    'Mathaai Hall',
    'Hall 2C',
    'Oteng Korankye II Hall',
    'Sisulu Hall',
    'Tawiah Hall',
    'Hall 2D',
    'Hall 2E',
    'New Hostel',

    // Centres & Institutions
    'Entrepreneurship, Innovation & Service Centre',

    // Faculty & Staff Housing
    'Leonard House',

    // Utilities
    'Water Treatment Plant',
    'Biodigester and Waste Treatment Plant',
  ];

  final List<String> categories = [
    'Electrical',
    'Plumbing',
    'Furniture',
    'AC / Ventilation',
    'Cleaning',
    'Security',
    'Other',
  ];

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _recordStatus = 'Microphone permission denied');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final path = '${appDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.openRecorder();
    await _recorder.startRecorder(toFile: path, codec: Codec.aacMP4);

    _recordDuration = Duration.zero;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
    setState(() {
      _isRecording = true;
      _audioPath = path;
      _recordStatus = 'Recording...';
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordStatus = 'Voice note recorded';
    });
  }

  Future<void> _playRecording() async {
    if (_audioPath == null) return;
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }
    final cleanPath = _audioPath!.replaceFirst('file://', '');
    await _audioPlayer.play(DeviceFileSource(cleanPath));
    setState(() => _isPlaying = true);
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });
  }

  Future<void> _captureLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationStatus = 'Please enable GPS/Location on your phone');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationStatus = 'Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus = 'Location permission permanently denied — enable in settings');
      return;
    }

    setState(() => _locationStatus = 'Getting location...');

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationStatus = 'Location captured ✓';
      });
    } catch (e) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationStatus = 'Location captured ✓ (low accuracy)';
        });
      } catch (e2) {
        setState(() => _locationStatus = 'Could not get location — try enabling GPS');
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: ashesiGold),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: ashesiGold),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    await _syncOfflineReports();

    if (_selectedBuilding == null ||
        _selectedCategory == null ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all fields'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/submit_report.php'),
      );

      request.fields['user_id'] = userId.toString();
      request.fields['building'] = _selectedBuilding!;
      request.fields['room'] = '';  // Send empty string
      request.fields['category'] = _selectedCategory!;
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['latitude'] = _latitude?.toString() ?? '';
      request.fields['longitude'] = _longitude?.toString() ?? '';

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', _selectedImage!.path));
      }

      if (_audioPath != null) {
        final cleanPath = _audioPath!.replaceFirst('file://', '');
        if (await File(cleanPath).exists()) {
          request.files.add(await http.MultipartFile.fromPath('audio', cleanPath));
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (!mounted) return;

      if (data['success']) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Report submitted successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      await DatabaseHelper.instance.insertReport({
        'user_id': userId,
        'building': _selectedBuilding,
        'room': '',
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'photo': _selectedImage?.path ?? '',
        'audio': _audioPath ?? '',           // ✅ ADDED
        'created_at': DateTime.now().toString(),
        'synced': 0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet — report saved offline and will sync later.'), // ✅ FIXED
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context);
    }

    setState(() => _isLoading = false);
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

        // ✅ ADDED: sync audio too
        if (report['audio'] != null && report['audio'] != '') {
          final cleanPath = report['audio'].toString().replaceFirst('file://', '');
          if (await File(cleanPath).exists()) {
            request.files.add(await http.MultipartFile.fromPath('audio', cleanPath));
          }
        }

        if (report['photo'] != '') {
          request.files.add(await http.MultipartFile.fromPath('photo', report['photo']));
        }

        var response = await request.send();
        if (response.statusCode == 200) {
          await DatabaseHelper.instance.markAsSynced(report['id']);
        }
      } catch (e) {
        // Ignore errors, retry later
      }
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B1F1F),
        foregroundColor: Colors.white,
        title: const Text('Report an Issue'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Issue Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBuilding,
              decoration: InputDecoration(
                labelText: 'Building',
                prefixIcon: const Icon(Icons.apartment),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              isExpanded: true,  // ✅ ADD THIS LINE
              items: buildings
                  .map((b) => DropdownMenuItem(
                value: b,
                child: Text(
                  b,
                  overflow: TextOverflow.ellipsis,  // ✅ ADD THIS
                  style: const TextStyle(fontSize: 13),  // ✅ ADD THIS
                ),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedBuilding = val),
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Issue Category',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the issue in detail...',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: ashesiGold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _locationStatus,
                      style: TextStyle(
                        color: _latitude != null ? Colors.green : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _captureLocation,
                    child: const Text('Capture',
                        style: TextStyle(color: ashesiGold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text('Voice Note (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: CircleAvatar(
                      backgroundColor: _isRecording ? Colors.red : const Color(0xFF8B1F1F),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isRecording
                          ? 'Recording: ${_recordDuration.inSeconds}s'
                          : _recordStatus,
                      style: TextStyle(
                        color: _audioPath != null ? Colors.green : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_audioPath != null && !_isRecording)
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.stop_circle : Icons.play_circle,
                        color: ashesiGold,
                      ),
                      onPressed: _playRecording,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text('Photo (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showImageOptions,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                )
                    : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Tap to add photo',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1F1F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Report',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}