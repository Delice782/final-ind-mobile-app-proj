import '../services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color primaryColor = Color(0xFF8B1F1F);

class EditReportScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final int userId;

  const EditReportScreen({
    Key? key,
    required this.report,
    required this.userId,
  }) : super(key: key);

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _descriptionController = TextEditingController();
  String? _selectedBuilding;
  String? _selectedCategory;
  bool _isLoading = false;

  final String baseUrl = 'http://169.239.251.102:280/~delice.ishimwe/datasphere';

  final List<String> buildings = [
    'Radichel Hall', 'Warren Library', 'Apt Hall', 'Jackson Hall',
    'Databank Foundation Hall', 'Ashesi Bookshop', 'King Engineering Building',
    'Nutor Hall', 'Fabrication Lab (Fab Lab)', 'Engineering Workshop',
    'The Hive', 'The Grill', 'Bliss Lounge', 'Natembea Health Centre',
    'Sports Centre', 'Basketball / Volleyball Courts', 'Isolation Wards',
    'Archer Cornfield Courtyard', 'Founders Plaza', 'Collins Courtyard',
    'Porters Lodge (Student Dorms)', 'Thacher Arboretum', 'Sutherland Hall',
    'Amu Hall', 'Mathaai Hall', 'Hall 2C', 'Oteng Korankye II Hall',
    'Sisulu Hall', 'Tawiah Hall', 'Hall 2D', 'Hall 2E', 'New Hostel',
    'Entrepreneurship, Innovation & Service Centre', 'Leonard House',
    'Water Treatment Plant', 'Biodigester and Waste Treatment Plant',
  ];

  final List<String> categories = [
    'Electrical', 'Plumbing', 'Furniture', 'AC / Ventilation',
    'Cleaning', 'Security', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.report['description'] ?? '';
    _selectedBuilding = widget.report['building'];
    _selectedCategory = widget.report['category'];
  }

  Future<void> _updateReport() async {
    if (_selectedBuilding == null ||
        _selectedCategory == null ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final id = widget.report['id'].toString();

    // Offline report — update SQLite directly, no server call
    if (id.startsWith('offline_')) {
      final localId = int.parse(id.replaceFirst('offline_', ''));
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'offline_reports',
        {
          'building': _selectedBuilding,
          'category': _selectedCategory,
          'description': _descriptionController.text.trim(),
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report updated!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
      return;
    }

    // Online report — send to server as before
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/edit_report.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'report_id': id,
          'user_id': widget.userId,
          'building': _selectedBuilding,
          'category': _selectedCategory,
          'description': _descriptionController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
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

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Edit Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Issue Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedBuilding,
              decoration: InputDecoration(
                labelText: 'Building',
                prefixIcon: const Icon(Icons.apartment),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              isExpanded: true,
              items: buildings
                  .map((b) => DropdownMenuItem(
                value: b,
                child: Text(b, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Update Report', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}