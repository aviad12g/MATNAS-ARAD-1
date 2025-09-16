import 'activity_definition.dart';
import 'attendance_session.dart';
import 'student.dart';
import 'user_account.dart';

class AppData {
  AppData({
    required this.users,
    required this.currentUserId,
    required this.activities,
    required this.students,
    required this.sessions,
  });

  final List<UserAccount> users;
  final String? currentUserId;
  final List<ActivityDefinition> activities;
  final List<Student> students;
  final List<AttendanceSession> sessions;

  factory AppData.empty() {
    return AppData(
      users: <UserAccount>[],
      currentUserId: null,
      activities: <ActivityDefinition>[],
      students: <Student>[],
      sessions: <AttendanceSession>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users': users.map((user) => user.toJson()).toList(),
      'currentUserId': currentUserId,
      'activities': activities.map((activity) => activity.toJson()).toList(),
      'students': students.map((student) => student.toJson()).toList(),
      'sessions': sessions.map((session) => session.toJson()).toList(),
    };
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'] as List<dynamic>? ?? <dynamic>[];
    final rawActivities = json['activities'] as List<dynamic>? ?? <dynamic>[];
    final rawStudents = json['students'] as List<dynamic>? ?? <dynamic>[];
    final rawSessions = json['sessions'] as List<dynamic>? ?? <dynamic>[];

    return AppData(
      users:
          rawUsers
              .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
              .toList(),
      currentUserId: json['currentUserId'] as String?,
      activities:
          rawActivities
              .map(
                (item) =>
                    ActivityDefinition.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      students:
          rawStudents
              .map((item) => Student.fromJson(item as Map<String, dynamic>))
              .toList(),
      sessions:
          rawSessions
              .map(
                (item) =>
                    AttendanceSession.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}
