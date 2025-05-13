import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lobby_provider.dart';
import '../services/lobby_service.dart';
import '../services/nfc_service.dart';
import '../models/student.dart';
import 'package:intl/intl.dart';
import '../models/lobby.dart';
import '../services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui'; // Add this import for ImageFilter

class ActiveLobbyScreen extends StatefulWidget {
  final String lobbyId;

  const ActiveLobbyScreen({super.key, required this.lobbyId});

  @override
  State<ActiveLobbyScreen> createState() => _ActiveLobbyScreenState();
}

class _ActiveLobbyScreenState extends State<ActiveLobbyScreen> {
  final NFCService _nfcService = NFCService();
  bool _nfcEnabled = false;
  String _searchQuery = '';
  late Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _initialLoad = _initializeData();
  }

  Future<void> _initializeData() async {
    final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);
    await lobbyProvider.fetchLobbyDetails(widget.lobbyId);
    await lobbyProvider.fetchAttendanceRecords(widget.lobbyId);
    await lobbyProvider.fetchActiveLobbies();
  }

  List<Student> _filterStudents(List<Map<String, dynamic>> records) {
    return records
        .where(
          (record) =>
              (record['student_name'] as String? ?? '').toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
              (record['student_system_id'] as String? ?? '')
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()),
        )
        .map(
          (record) => Student(
            name: record['student_name'] as String,
            id: record['student_system_id'] as String,
            timestamp: DateTime.parse(record['recorded_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> _toggleNFCScanning(bool enabled) async {
    if (enabled) {
      if (!await _nfcService.isNFCAvailable()) {
        setState(() => _nfcEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not available on this device')),
        );
        return;
      }

      await _nfcService.startScanning((data) => _handleNFCData(data));
    } else {
      await _nfcService.stopScanning();
    }
    setState(() => _nfcEnabled = enabled);
  }

  Future<void> _handleNFCData(Map<String, dynamic> data) async {
    final lobbyService = Provider.of<LobbyService>(context, listen: false);
    final student = Student(
      id: data['Block 1']?.toString() ?? '',
      name: data['Block 4']?.toString() ?? 'Unknown Student',
    );

    try {
      await lobbyService.addAttendanceRecord(widget.lobbyId, student);
      context.read<LobbyProvider>().fetchAttendanceRecords(widget.lobbyId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked attendance for ${student.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error marking attendance: $e')));
    }
  }

  Future<void> _showManualEntryDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final idController = TextEditingController();
    final lobbyService = Provider.of<LobbyService>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student Manually'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Student ID'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
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
                final student = Student(
                  name: nameController.text,
                  id: idController.text,
                );
                try {
                  await lobbyService.addAttendanceRecord(
                    widget.lobbyId,
                    student,
                  );
                  context.read<LobbyProvider>().fetchAttendanceRecords(
                        widget.lobbyId,
                      );
                  Navigator.pop(context);
                } catch (e) {
                  Navigator.pop(
                    context,
                  ); // Close dialog before showing error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceAll('Exception: ', ''),
                      ),
                      duration: const Duration(seconds: 0),
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLobbyData() async {
    // Show loading indicator
    if (!context.mounted) return;
    final scaffold = ScaffoldMessenger.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black45,
        alignment: Alignment.center,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Preparing export...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      Overlay.of(context).insert(overlayEntry);

      final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);

      // Refresh data to ensure we have the latest
      await lobbyProvider.fetchAttendanceRecords(widget.lobbyId);
      await lobbyProvider.fetchLobbyDetails(widget.lobbyId);

      final attendanceRecords = lobbyProvider.attendanceRecords;

      if (attendanceRecords.isEmpty) {
        overlayEntry.remove();
        if (context.mounted) {
          scaffold.showSnackBar(
            const SnackBar(content: Text('No attendance records to export')),
          );
        }
        return;
      }

      // Try multiple approaches to get the lobby name
      String lobbyName = 'Unnamed Lobby';

      // Approach 1: Get from currentLobby in provider
      final currentLobby = lobbyProvider.currentLobby;
      if (currentLobby != null && currentLobby['name'] != null) {
        lobbyName = currentLobby['name'] as String;
      }
      // Approach 2: Try to find in activeLobbies
      else {
        final matchingLobby = lobbyProvider.activeLobbies.firstWhere(
          (lobby) => lobby.id == widget.lobbyId,
          orElse: () => Lobby(
            id: widget.lobbyId,
            name: 'Lobby-${widget.lobbyId.substring(0, 6)}',
            entryCode: '',
            hostId: '',
            active: true,
            createdAt: DateTime.now(),
            memberCount: 0,
            attendanceCount: attendanceRecords.length,
          ),
        );

        if (matchingLobby.name.isNotEmpty) {
          lobbyName = matchingLobby.name;
        }
      }

      // Generate CSV content
      final csvContent = _generateCsvContent(attendanceRecords, lobbyName);
      if (csvContent.isEmpty) {
        throw Exception('Failed to generate CSV content');
      }

      // Create temporary file
      final directory = await getTemporaryDirectory();
      final sanitizedName = lobbyName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${directory.path}/${sanitizedName}_attendance.csv');
      await file.writeAsString(csvContent);

      // Remove the loading indicator
      overlayEntry.remove();

      if (!context.mounted) return;

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance data from $lobbyName',
        subject: 'Attendance Report - $lobbyName',
      );
    } catch (e) {
      // Make sure to remove the overlay even if there's an error
      overlayEntry.remove();

      if (context.mounted) {
        print('Export error: $e');
        scaffold.showSnackBar(
          SnackBar(
              content: Text(
                  'Export failed: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  String _generateCsvContent(
      List<Map<String, dynamic>> attendanceRecords, String lobbyName) {
    final now = DateTime.now();
    final date = DateFormat('M/d/yyyy').format(now);
    final time = DateFormat('HH:mm:ss').format(now);

    // Generate CSV header rows
    List<String> rows = [
      'Markme:,Attendance Record',
      'Lobby:,${_sanitizeCSVField(lobbyName)}',
      'Date:,${_sanitizeCSVField(date)}',
      'Time:,${_sanitizeCSVField(time)}',
      'Total Records:,${attendanceRecords.length}',
      '', // Empty row
      'Student ID,Name,Recorded At' // Column headers
    ];

    // Sort records by recorded_at time if available
    final sortedRecords = List<Map<String, dynamic>>.from(attendanceRecords);
    sortedRecords.sort((a, b) {
      final aTime = a['recorded_at'] != null
          ? DateTime.parse(a['recorded_at'] as String)
          : DateTime(1970);
      final bTime = b['recorded_at'] != null
          ? DateTime.parse(b['recorded_at'] as String)
          : DateTime(1970);
      return bTime.compareTo(aTime); // Most recent first
    });

    // Add student attendance rows
    for (var record in sortedRecords) {
      final studentId =
          _sanitizeCSVField(record['student_system_id'] as String? ?? '');
      final studentName =
          _sanitizeCSVField(record['student_name'] as String? ?? '');

      String recordedTime = '';
      if (record['recorded_at'] != null) {
        try {
          final recordedAt = DateTime.parse(record['recorded_at'] as String);
          recordedTime = DateFormat('HH:mm:ss').format(recordedAt);
        } catch (e) {
          recordedTime = 'Invalid time';
        }
      }

      rows.add('$studentId,$studentName,${_sanitizeCSVField(recordedTime)}');
    }

    return rows.join('\n');
  }

  String _sanitizeCSVField(String field) {
    if (field.isEmpty) return '';

    // If the field contains commas, quotes, or newlines, wrap it in quotes and escape any existing quotes
    if (field.contains(RegExp(r'[,"\n\r]'))) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  @override
  Widget build(BuildContext context) {
    final lobbyProvider = Provider.of<LobbyProvider>(context);
    final currentLobby = lobbyProvider.activeLobbies.firstWhere(
      (lobby) => lobby.id == widget.lobbyId,
      orElse: () => Lobby(
        id: '',
        name: '',
        entryCode: '',
        hostId: '',
        active: false,
        createdAt: DateTime.now(),
        memberCount: 0,
        attendanceCount: 0,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLobby.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLobbyData,
            tooltip: 'Export Attendance',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Tooltip(
              message: _nfcEnabled
                  ? 'Disable NFC Card Scanning'
                  : 'Enable NFC Card Scanning',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28.0),
                  onTap: () => _toggleNFCScanning(!_nfcEnabled),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: _nfcEnabled
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(28.0),
                      border: Border.all(
                        color: _nfcEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.nfc_rounded,
                          size: 20,
                          color: _nfcEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _nfcEnabled ? 'On' : 'Off',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: _nfcEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontWeight: _nfcEnabled
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () =>
                lobbyProvider.fetchAttendanceRecords(widget.lobbyId),
            tooltip: 'Sync Attendance',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showManualEntryDialog,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _initialLoad,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return Column(
            children: [
              if (currentLobby.hostId ==
                  Provider.of<AuthService>(context).currentUser?.id)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 0,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Host Controls',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildEnhancedStatItem(
                                  context,
                                  Icons.group_rounded,
                                  'Members',
                                  '${currentLobby.memberCount}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEnhancedStatItem(
                                  context,
                                  Icons.checklist_rounded,
                                  'Checked In',
                                  '${currentLobby.attendanceCount}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEnhancedStatItem(
                                  context,
                                  Icons.key_rounded,
                                  'Entry Code',
                                  currentLobby.entryCode,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name or ID',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 16.0,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.info_outline_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Lobby Info'),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow(
                                      context,
                                      'Host ID',
                                      currentLobby.hostId,
                                      Icons.person_outline_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      context,
                                      'Entry Code',
                                      currentLobby.entryCode,
                                      Icons.key_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      context,
                                      'Created',
                                      DateFormat.yMd().add_jm().format(currentLobby.createdAt),
                                      Icons.calendar_today_rounded,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Close',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ),
                            tooltip: 'View Lobby Information',
                          ),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total Students: ${lobbyProvider.attendanceRecords.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildStudentList(lobbyProvider.attendanceRecords),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentList(List<Map<String, dynamic>> records) {
    final students = _filterStudents(records);

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
                    ? 'No students in attendance yet.'
                    : 'No students found for "$_searchQuery"',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    'Students will appear here when they join.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ),
            title: Text(
              student.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'ID: ${student.id}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _getTimeAgo(student.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  void dispose() {
    _nfcService.stopScanning();
    super.dispose();
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

Widget _buildEnhancedStatItem(
    BuildContext context, IconData icon, String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16.0),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        width: 1.0,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
