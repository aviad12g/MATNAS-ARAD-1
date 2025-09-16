class Student {
  Student({
    required this.id,
    required this.fullName,
    required this.activityId,
    required this.groupId,
  });

  final String id;
  final String fullName;
  final String activityId;
  final String groupId;

  Student copyWith({
    String? id,
    String? fullName,
    String? activityId,
    String? groupId,
  }) {
    return Student(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      activityId: activityId ?? this.activityId,
      groupId: groupId ?? this.groupId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'activityId': activityId,
      'groupId': groupId,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      activityId: json['activityId'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
    );
  }
}
