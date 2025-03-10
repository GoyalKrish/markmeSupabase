import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lobby_provider.dart';
import '../services/lobby_service.dart';
import '../services/nfc_service.dart';
import '../models/student.dart';
import '../components/nfc_result_dialog.dart';
import 'package:intl/intl.dart';
import '../models/lobby.dart';

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
    await lobbyProvider.fetchAttendanceRecords(widget.lobbyId);
  }

  List<Student> _filterStudents(List<Map<String, dynamic>> records) {
    return records
        .where((record) =>
            (record['student_name'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (record['student_id'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
        .map((record) => Student(
              name: record['student_name'] as String,
              id: record['student_id'] as String,
              timestamp: DateTime.parse(record['created_at'] as String),
            ))
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking attendance: $e')),
      );
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
                decoration: const InputDecoration(labelText: 'Student Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Student ID'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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
                  await lobbyService.addAttendanceRecord(widget.lobbyId, student);
                  context.read<LobbyProvider>().fetchAttendanceRecords(widget.lobbyId);
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding student: $e')),
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
          Switch(
            value: _nfcEnabled,
            onChanged: _toggleNFCScanning,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => lobbyProvider.fetchAttendanceRecords(widget.lobbyId),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search students',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
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
                              Text('Entry Code: ${currentLobby.entryCode}'),
                              Text('Created: ${DateFormat.yMd().add_jm().format(currentLobby.createdAt)}'),
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
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Total Students: ${lobbyProvider.attendanceRecords.length}',
                  style: Theme.of(context).textTheme.titleLarge,
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

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return ListTile(
          title: Text(student.name),
          subtitle: Text('ID: ${student.id}'),
          trailing: Text(_getTimeAgo(student.timestamp)),
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
} 