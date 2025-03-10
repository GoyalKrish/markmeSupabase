import 'package:flutter/material.dart';

class NFCResultDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onMarkAttendance;

  const NFCResultDialog({
    super.key,
    required this.data,
    required this.onMarkAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('NFC Scan Results'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: data.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onMarkAttendance();
            Navigator.pop(context);
          },
          child: const Text('Mark Attendance'),
        ),
      ],
    );
  }
} 