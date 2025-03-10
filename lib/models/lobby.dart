class Lobby {
  final String id;
  final String name;
  final String entryCode;
  final String hostId;
  final bool active;
  final DateTime createdAt;
  final int memberCount;
  final int attendanceCount;

  Lobby({
    required this.id,
    required this.name,
    required this.entryCode,
    required this.hostId,
    required this.active,
    required this.createdAt,
    required this.memberCount,
    required this.attendanceCount,
  });

  factory Lobby.fromJson(Map<String, dynamic> json) {
    return Lobby(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Lobby',
      entryCode: json['entry_code'] as String,
      hostId: json['host_id'] as String,
      active: json['active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberCount: json['lobby_members'] == null 
          ? 0 
          : (json['lobby_members'] is Map<String, dynamic>
              ? (json['lobby_members'] as Map<String, dynamic>)['count'] as int? ?? 0
              : (json['lobby_members'] as List).length),
      attendanceCount: json['attendance_records'] == null 
          ? 0 
          : (json['attendance_records'] is Map<String, dynamic>
              ? (json['attendance_records'] as Map<String, dynamic>)['count'] as int? ?? 0
              : (json['attendance_records'] as List).length),
    );
  }
} 