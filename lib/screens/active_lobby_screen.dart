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
import 'dart:ui';
import '../theme/markme_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/notification_extensions.dart';

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
        context.showErrorNotification('NFC is not available on this device');
        return;
      }

      await _nfcService.startScanning((data) => _handleNFCData(data));
      context.showInfoNotification('NFC Scanning Active');
    } else {
      await _nfcService.stopScanning();
      if (mounted) {
        context.showInfoNotification('NFC Scanning Stopped');
      }
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
      context.showSuccessNotification('Marked attendance for ${student.name}');
    } catch (e) {
      context.showErrorNotification('Error marking attendance: $e');
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
                  context.showErrorNotification(
                    e.toString().replaceAll('Exception: ', ''),
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
  // Show dialog to choose export type
  final exportType = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export Attendance'),
      content: const Text('Choose export format:'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop('simple'),
            child: const Text('Simple Export'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('ezone'),
          child: const Text('Export to Ezone'),
        ),
      ],
    ),
  );

  if (exportType == null) return; // User dismissed dialog

      // Handle export type
      final isEzoneExport = exportType == 'ezone';

  // Now proceed with export
  if (!context.mounted) return;
  final overlayEntry = OverlayEntry(
    builder: (context) => Container(
      color: Colors.black45,
      alignment: Alignment.center,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
    await lobbyProvider.fetchAttendanceRecords(widget.lobbyId);
    await lobbyProvider.fetchLobbyDetails(widget.lobbyId);
    final attendanceRecords = lobbyProvider.attendanceRecords;

    if (attendanceRecords.isEmpty) {
      overlayEntry.remove();
      if (context.mounted) {
        context.showInfoNotification('No attendance records to export');
      }
      return;
    }

    // Get lobby name
    String lobbyName = 'Unnamed Lobby';
    final currentLobby = lobbyProvider.currentLobby;
    if (currentLobby != null && currentLobby['name'] != null) {
      lobbyName = currentLobby['name'] as String;
    } else {
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

    // Generate CSV content based on export type
    String csvContent;
    String fileNameSuffix = '';

    if (isEzoneExport) {
      csvContent = _generateEzoneCsvContent(attendanceRecords);
      fileNameSuffix = '_ezone';
    } else {
      csvContent = _generateCsvContent(attendanceRecords, lobbyName);
      fileNameSuffix = '_simple';
    }

    // Create temporary file
    final directory = await getTemporaryDirectory();
    final sanitizedName = lobbyName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final file = File('${directory.path}/${sanitizedName}_attendance$fileNameSuffix.csv');
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
    // Remove overlay and show error
    overlayEntry.remove();
    if (context.mounted) {
      print('Export error: $e');
      context.showErrorNotification(
          'Export failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }
}


  String _generateEzoneCsvContent(List<Map<String, dynamic>> attendanceRecords) {
    return attendanceRecords
    .map((record) => record['student_system_id'] as String? ?? '')
    .join('\n');
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
        title: Text(
          currentLobby.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLobbyData,
            tooltip: 'Export Attendance',
            color: MarkMeTheme.primaryWhite.withOpacity(0.9),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () =>
                lobbyProvider.fetchAttendanceRecords(widget.lobbyId),
            tooltip: 'Sync Attendance',
            color: MarkMeTheme.primaryWhite.withOpacity(0.9),
          ),
          const SizedBox(width: 16),
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
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: MarkMeTheme.primaryYellow.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    color: MarkMeTheme.surfaceDark,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: MarkMeTheme.primaryYellow,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Host Controls',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: MarkMeTheme.primaryWhite,
                                    ),
                                  ),
                                ],
                              ),
                              Semantics(
                                label: _nfcEnabled
                                    ? 'Stop NFC Scanning'
                                    : 'Start NFC Scanning',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _nfcEnabled
                                        ? MarkMeTheme.primaryYellow
                                        : MarkMeTheme.surfaceDark,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: _nfcEnabled
                                          ? MarkMeTheme.primaryYellow
                                          : MarkMeTheme.primaryWhite
                                              .withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () =>
                                          _toggleNFCScanning(!_nfcEnabled),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _nfcEnabled
                                                ? Icons.nfc
                                                : Icons.nfc_outlined,
                                            color: _nfcEnabled
                                                ? MarkMeTheme.darkBackground
                                                : MarkMeTheme.primaryWhite
                                                    .withOpacity(0.9),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _nfcEnabled ? 'Active' : 'Inactive',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: _nfcEnabled
                                                  ? MarkMeTheme.darkBackground
                                                  : MarkMeTheme.primaryWhite
                                                      .withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                Icons.group,
                                '${currentLobby.memberCount}',
                                'Members',
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color:
                                    MarkMeTheme.primaryWhite.withOpacity(0.1),
                              ),
                              _buildStatItem(
                                Icons.checklist_rtl,
                                '${currentLobby.attendanceCount}',
                                'Attendance',
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color:
                                    MarkMeTheme.primaryWhite.withOpacity(0.1),
                              ),
                              _buildStatItem(
                                Icons.key,
                                currentLobby.entryCode,
                                'Entry Code',
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
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Lobby Info'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Host ID: ${currentLobby.hostId}'),
                              Text(
                                'Entry Code: ${currentLobby.entryCode}',
                              ),
                              Text(
                                'Created: ${DateFormat.yMd().add_jm().format(currentLobby.createdAt)}',
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Total Students: ${lobbyProvider.attendanceRecords.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
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
                    'Scan NFC Tags or enter student manually.',
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

    // Sort students by timestamp in descending order (newest first)
    students.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final isNewEntry =
            DateTime.now().difference(student.timestamp).inMinutes < 1;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          transform: isNewEntry
              ? (Matrix4.identity()..scale(1.02))
              : Matrix4.identity(),
          child: Card(
            elevation: isNewEntry ? 4.0 : 2.0,
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              leading: CircleAvatar(
                backgroundColor: isNewEntry
                    ? MarkMeTheme.primaryYellow
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isNewEntry
                        ? MarkMeTheme.darkBackground
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Text(
                student.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isNewEntry ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${student.id}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _getTimeAgo(student.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isNewEntry
                              ? MarkMeTheme.primaryYellow
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
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

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: MarkMeTheme.primaryYellow,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MarkMeTheme.primaryWhite,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MarkMeTheme.primaryWhite.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
