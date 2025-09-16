enum AttendanceStatus { present, absent }

AttendanceStatus statusFromString(String value) {
  switch (value) {
    case 'present':
      return AttendanceStatus.present;
    case 'absent':
    default:
      return AttendanceStatus.absent;
  }
}

String statusToString(AttendanceStatus status) {
  return status == AttendanceStatus.present ? 'present' : 'absent';
}

class AttendanceSession {
  AttendanceSession({
    required this.id,
    required this.activityId,
    required this.groupId,
    required this.activityName,
    required this.groupName,
    required this.date,
    required this.isClosed,
    required Map<String, AttendanceStatus> statuses,
  }) : statuses = Map<String, AttendanceStatus>.from(statuses);

  final String id;
  final String activityId;
  final String groupId;
  final String activityName;
  final String groupName;
  final DateTime date;
  final bool isClosed;
  final Map<String, AttendanceStatus> statuses;

  AttendanceSession copyWith({
    String? id,
    String? activityId,
    String? groupId,
    String? activityName,
    String? groupName,
    DateTime? date,
    bool? isClosed,
    Map<String, AttendanceStatus>? statuses,
  }) {
    return AttendanceSession(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      groupId: groupId ?? this.groupId,
      activityName: activityName ?? this.activityName,
      groupName: groupName ?? this.groupName,
      date: date ?? this.date,
      isClosed: isClosed ?? this.isClosed,
      statuses: statuses ?? this.statuses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityId': activityId,
      'groupId': groupId,
      'activityName': activityName,
      'groupName': groupName,
      'date': date.toIso8601String(),
      'isClosed': isClosed,
      'statuses': statuses.map(
        (studentId, status) => MapEntry(studentId, statusToString(status)),
      ),
    };
  }

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    final rawStatuses =
        json['statuses'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return AttendanceSession(
      id: json['id'] as String,
      activityId: json['activityId'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      activityName: json['activityName'] as String? ?? '',
      groupName: json['groupName'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      isClosed: json['isClosed'] as bool? ?? false,
      statuses: rawStatuses.map(
        (studentId, value) =>
            MapEntry(studentId, statusFromString(value as String? ?? 'absent')),
      ),
    );
  }
}
