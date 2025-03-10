class Student {
  final String name;
  final String id;
  final DateTime timestamp;

  Student({
    required this.name,
    required this.id,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    name: json['name'],
    id: json['id'],
    timestamp: json['timestamp'] != null 
      ? DateTime.parse(json['timestamp'])
      : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'timestamp': timestamp.toIso8601String(),
  };
} 