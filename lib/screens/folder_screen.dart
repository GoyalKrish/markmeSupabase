import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/folder_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/nfc_service.dart';
import '../components/nfc_result_dialog.dart';
import 'package:intl/intl.dart';

class FolderScreen extends StatefulWidget {
  final String folderName;
  final FolderService folderService;

  const FolderScreen({
    super.key,
    required this.folderName,
    required this.folderService,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late Future<List<Student>> _studentsFuture;
  String _searchQuery = '';
  final NFCService _nfcService = NFCService();
  bool _nfcEnabled = false;

  @override
  void initState() {
    super.initState();
    _refreshStudents();
  }

  void _refreshStudents() {
    setState(() {
      _studentsFuture = widget.folderService.getStudents(widget.folderName);
    });
  }

  Future<bool> _isDuplicate(String studentId) async {
    final students = await widget.folderService.getStudents(widget.folderName);
    return students.any((student) => student.id == studentId);
  }

  void _showManualEntryDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Student Manually'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter student name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter student ID';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Check for duplicate ID after basic validation
                  if (await _isDuplicate(idController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A student with this ID already exists'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  final student = Student(
                    name: nameController.text,
                    id: idController.text,
                  );
                  await widget.folderService.addStudent(widget.folderName, student);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _refreshStudents();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${student.name} to the list'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  List<Student> _filterStudents(List<Student> students) {
    if (_searchQuery.isEmpty) return students;
    final query = _searchQuery.toLowerCase();
    return students.where((student) =>
      student.name.toLowerCase().contains(query) ||
      student.id.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _shareFolderData() async {
    try {
      final students = await widget.folderService.getStudents(widget.folderName);
      final csvContent = _generateCsvContent(students);
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${widget.folderName}_attendance.csv');
      await file.writeAsString(csvContent);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance data from ${widget.folderName}',
        subject: 'Attendance Report - ${widget.folderName}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  String _generateCsvContent(List<Student> students) {
    final now = DateTime.now();
    final date = DateFormat('M/d/yyyy').format(now);
    final time = DateFormat('HH:mm:ss').format(now);
    
    List<String> rows = [
      'Markme :,Attendance Record,',
      'Class,${widget.folderName},',
      'Date,$date,',
      'Time,$time,',
      'Total Students,${students.length},',
      ',,',  // Empty row
      'Student ID,Name,Time'  // Headers without trailing comma
    ];

    // Sort students by name if needed
    // students.sort((a, b) => a.name.compareTo(b.name));

    // Add student rows without trailing commas
    for (var student in students) {
      final studentTime = DateFormat('HH:mm:ss').format(student.timestamp);
      rows.add('${student.id},${_sanitizeCSVField(student.name)},$studentTime');
    }

    return rows.join('\n');
  }

  String _sanitizeCSVField(String field) {
    // If the field contains commas, quotes, or newlines, wrap it in quotes and escape any existing quotes
    if (field.contains(RegExp(r'[,"\n\r]'))) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  Future<void> _toggleNFCScanning(bool enabled) async {
    if (enabled) {
      if (!await _nfcService.isNFCAvailable()) {
        setState(() => _nfcEnabled = false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC is not available on this device'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      try {
        await _nfcService.startScanning(_handleNFCData);
        setState(() => _nfcEnabled = true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC scanning enabled. Hold cards near device to scan.'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        setState(() => _nfcEnabled = false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enabling NFC: $e')),
        );
      }
    } else {
      await _nfcService.stopScanning();
      setState(() => _nfcEnabled = false);
    }
  }

  Future<void> _handleNFCData(Map<String, dynamic> scannedData) async {
    if (!context.mounted) return;

    // Extract student ID from Block 1 and name from Block 4
    String studentId = scannedData['Block 1'] ?? '';
    String name = scannedData['Block 4'] ?? '';

    if (studentId.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid card data: Missing student information'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check for duplicate ID
    if (await _isDuplicate(studentId)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Student with ID $studentId already exists in this folder'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Add the new student
    final student = Student(
      name: name,
      id: studentId,
    );

    await widget.folderService.addStudent(widget.folderName, student);
    _refreshStudents();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $name (ID: $studentId) to the list'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nfcService.stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          Switch(
            value: _nfcEnabled,
            onChanged: _toggleNFCScanning,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFolderData,
            tooltip: 'Share Folder Data',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showManualEntryDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search students',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.length : 0;
                return Text(
                  'Total Students: $count',
                  style: Theme.of(context).textTheme.titleLarge,
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final students = _filterStudents(snapshot.data ?? []);
                
                if (students.isEmpty) {
                  return Center(child: Text(
                    _searchQuery.isEmpty 
                      ? 'No students added yet'
                      : 'No students found for "$_searchQuery"'
                  ));
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: Text('Are you sure you want to remove ${student.name}?'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text(
                                    'DELETE',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        _deleteStudent(student, index);
                      },
                      child: ListTile(
                        title: Text(student.name),
                        subtitle: Text('ID: ${student.id}'),
                        trailing: Text(
                          _getTimeAgo(student.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _deleteStudent(Student student, int index) async {
    // Store the student and index for potential undo
    final students = await widget.folderService.getStudents(widget.folderName);
    
    // Remove the student
    students.removeAt(index);
    await widget.folderService.saveStudents(widget.folderName, students);
    
    // Refresh the list
    _refreshStudents();

    if (!context.mounted) return;
    
    // Show snackbar with undo option
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${student.name} removed from the list'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            // Restore the student
            final currentStudents = await widget.folderService.getStudents(widget.folderName);
            currentStudents.insert(index, student);
            await widget.folderService.saveStudents(widget.folderName, currentStudents);
            _refreshStudents();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
} 