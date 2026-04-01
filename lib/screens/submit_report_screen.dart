import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_sms/flutter_sms.dart';
import '../services/database_helper.dart';

const Color ashesiGold = Color(0xFFFFD700); // Gold color for unified theme

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _descriptionController = TextEditingController();
  String? _selectedBuilding;
  String? _selectedRoom;
  String? _selectedCategory;
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final String baseUrl = 'http://10.255.238.71/datasphere';

  final List<String> buildings = [
    'Main Academic Block',
    'Engineering Block',
    'Residential Block A',
    'Residential Block B',
    'Library',
    'Cafeteria',
    'Sports Complex',
    'Admin Block',
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

  final List<String> rooms = List.generate(20, (i) => 'Room ${i + 1}');

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _sendSMSAlert(String building, String room, String category) async {
    String message =
        'New DataSphere Report!\nCategory: $category\nLocation: $building - $room\nPlease check the dashboard.';

    List<String> recipients = ['+233256439757']; // Replace with real number

    try {
      await sendSMS(message: message, recipients: recipients);
    } catch (e) {
      // Fail silently
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
        _selectedRoom == null ||
        _selectedCategory == null ||
        _descriptionController.text.isEmpty) {
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
      request.fields['room'] = _selectedRoom!;
      request.fields['category'] = _selectedCategory!;
      request.fields['description'] = _descriptionController.text;

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', _selectedImage!.path));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (!mounted) return;

      if (data['success']) {
        await _sendSMSAlert(_selectedBuilding!, _selectedRoom!, _selectedCategory!);

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
        'room': _selectedRoom,
        'category': _selectedCategory,
        'description': _descriptionController.text,
        'photo': _selectedImage?.path ?? '',
        'created_at': DateTime.now().toString(),
        'synced': 0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No internet! Report saved offline and will sync automatically.'),
            backgroundColor: Colors.orange),
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
        request.fields['room'] = report['room'];
        request.fields['category'] = report['category'];
        request.fields['description'] = report['description'];

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
              items: buildings
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedBuilding = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRoom,
              decoration: InputDecoration(
                labelText: 'Room',
                prefixIcon: const Icon(Icons.door_front_door_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: rooms
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedRoom = val),
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