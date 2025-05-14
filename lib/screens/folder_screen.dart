import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/folder_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/nfc_service.dart';
import 'package:intl/intl.dart';
import '../utils/notification_extensions.dart';

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
                    context.showWarningNotification(
                        'A student with this ID already exists');
                    return;
                  }

                  final student = Student(
                    name: nameController.text,
                    id: idController.text,
                  );
                  await widget.folderService
                      .addStudent(widget.folderName, student);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _refreshStudents();
                    context.showSuccessNotification(
                        'Added ${student.name} to the list');
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
    return students
        .where((student) =>
            student.name.toLowerCase().contains(query) ||
            student.id.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _shareFolderData() async {
    try {
      final students =
          await widget.folderService.getStudents(widget.folderName);
      final csvContent = _generateCsvContent(students);

      final directory = await getTemporaryDirectory();
      final file =
          File('${directory.path}/${widget.folderName}_attendance.csv');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance data from ${widget.folderName}',
        subject: 'Attendance Report - ${widget.folderName}',
      );
    } catch (e) {
      if (context.mounted) {
        context.showErrorNotification('Export failed: $e');
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
      ',,', // Empty row
      'Student ID,Name,Time' // Headers without trailing comma
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
        context.showErrorNotification('NFC is not available on this device');
        return;
      }

      try {
        await _nfcService.startScanning(_handleNFCData);
        setState(() => _nfcEnabled = true);
        if (!context.mounted) return;
        context.showInfoNotification(
            'NFC scanning enabled. Hold cards near device to scan.');
      } catch (e) {
        setState(() => _nfcEnabled = false);
        if (!context.mounted) return;
        context.showErrorNotification('Error enabling NFC: $e');
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
      context.showErrorNotification(
          'Invalid card data: Missing student information');
      return;
    }

    // Check for duplicate ID
    if (await _isDuplicate(studentId)) {
      if (!context.mounted) return;
      context.showWarningNotification(
          'Student with ID $studentId already exists in this folder');
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
    context.showSuccessNotification('Added $name (ID: $studentId) to the list');
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Tooltip(
              message:
                  _nfcEnabled ? 'Disable NFC Scanning' : 'Enable NFC Scanning',
              child: Switch(
                value: _nfcEnabled,
                onChanged: _toggleNFCScanning,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareFolderData,
            tooltip: 'Share Folder Data',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManualEntryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
        tooltip: 'Add Student Manually',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or ID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.5),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                final count = snapshot.hasData
                    ? _filterStudents(snapshot.data!).length
                    : 0;
                final totalCount = snapshot.hasData ? snapshot.data!.length : 0;
                String displayText = 'Total Students: $totalCount';
                if (_searchQuery.isNotEmpty && snapshot.hasData) {
                  displayText = 'Found: $count / $totalCount';
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red[700], size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading students.',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final students = _filterStudents(snapshot.data ?? []);

                if (students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.6),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No students added yet.'
                                : 'No students found for "$_searchQuery"',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchQuery.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                'Tap the "+" button to add a student.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.7),
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 8.0),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      elevation: 2.0,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 6.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Dismissible(
                        key: ValueKey(student.id), // Use a stable key
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(Icons.delete_sweep_outlined,
                                  color: Colors.white),
                              SizedBox(width: 8),
                              Text('Remove',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: Text(
                                    'Are you sure you want to remove ${student.name}? This action cannot be undone immediately from here.'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('CANCEL'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text(
                                      'DELETE',
                                      style: TextStyle(color: Colors.red[700]),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          // Find the original index before filtering for deletion
                          final originalStudents = snapshot.data ?? [];
                          final originalIndex = originalStudents
                              .indexWhere((s) => s.id == student.id);
                          if (originalIndex != -1) {
                            _deleteStudent(student, originalIndex);
                          } else {
                            // Fallback if student not found in original list (should not happen)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Error: Could not find student to delete.')),
                            );
                          }
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              student.name.isNotEmpty
                                  ? student.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            student.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Text(
                            'ID: ${student.id}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          trailing: Text(
                            _getTimeAgo(student.timestamp),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
    // final students = await widget.folderService.getStudents(widget.folderName);
    // The 'index' parameter for _deleteStudent should be the index in the unfiltered list.
    // The way it was called from onDismissed was using the filtered list's index.
    // We need to ensure we are removing the correct student from the source.

    final allStudents =
        await widget.folderService.getStudents(widget.folderName);
    // Find the actual student object in the full list to ensure we have the correct one
    // This is safer than relying on index if the list could have changed elsewhere.
    final studentToRemove = allStudents.firstWhere((s) => s.id == student.id,
        orElse: () => student /* fallback, though should be found */);
    final actualIndex = allStudents.indexOf(studentToRemove);

    if (actualIndex == -1) {
      // This case should ideally not be reached if student was in snapshot.data
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: Student not found for deletion.')),
        );
      }
      _refreshStudents(); // Refresh to be safe
      return;
    }

    // Remove the student using the correct index from the full list
    allStudents.removeAt(actualIndex);
    await widget.folderService.saveStudents(widget.folderName, allStudents);

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
            final currentStudents =
                await widget.folderService.getStudents(widget.folderName);
            // Insert back at the original position if possible, or at the end
            currentStudents.insert(
                actualIndex < currentStudents.length
                    ? actualIndex
                    : currentStudents.length,
                studentToRemove);
            await widget.folderService
                .saveStudents(widget.folderName, currentStudents);
            _refreshStudents();
          },
        ),
        duration: const Duration(seconds: 4), // Increased duration for undo
      ),
    );
  }
}
