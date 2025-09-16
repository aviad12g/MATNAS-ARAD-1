import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_definition.dart';
import '../models/app_data.dart';
import '../models/attendance_session.dart';
import '../models/student.dart';
import '../models/user_account.dart';
import '../services/local_storage_service.dart';

class AppStateException implements Exception {
  AppStateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final LocalStorageService _storage;
  final Uuid _uuid = const Uuid();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  bool _initialized = false;
  bool _isSaving = false;
  bool _pendingSave = false;

  List<UserAccount> _users = <UserAccount>[];
  UserAccount? _currentUser;
  List<ActivityDefinition> _activities = <ActivityDefinition>[];
  List<Student> _students = <Student>[];
  List<AttendanceSession> _sessions = <AttendanceSession>[];

  bool get isInitialized => _initialized;
  UserAccount? get currentUser => _currentUser;

  List<ActivityDefinition> get activities =>
      List<ActivityDefinition>.unmodifiable(_activities);
  List<Student> get students => List<Student>.unmodifiable(_students);
  List<AttendanceSession> get sessions =>
      List<AttendanceSession>.unmodifiable(_sessions);

  Future<void> initialize() async {
    final data = await _storage.load();
    _users = List<UserAccount>.from(data.users);
    _activities = List<ActivityDefinition>.from(data.activities);
    _students = List<Student>.from(data.students);
    _sessions = List<AttendanceSession>.from(data.sessions);
    _currentUser = _findUserById(data.currentUserId);

    if (_activities.isEmpty && _students.isEmpty) {
      _seedInitialData();
    }

    _initialized = true;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final hashed = _hashPassword(password);

    final user = _users.firstWhere(
      (candidate) =>
          candidate.email.trim().toLowerCase() == normalizedEmail &&
          candidate.passwordHash == hashed,
      orElse: () => throw AppStateException('כתובת הדוא"ל או הסיסמה שגויים.'),
    );

    _currentUser = user;
    notifyListeners();
    await _persist();
  }

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw AppStateException('יש להזין כתובת דוא"ל.');
    }

    if (_users.any(
      (user) => user.email.trim().toLowerCase() == normalizedEmail,
    )) {
      throw AppStateException('כתובת הדוא"ל כבר קיימת במערכת.');
    }

    final account = UserAccount(
      id: _uuid.v4(),
      displayName:
          displayName.trim().isEmpty ? 'משתמש חדש' : displayName.trim(),
      email: normalizedEmail,
      passwordHash: _hashPassword(password),
    );

    _users = List<UserAccount>.from(_users)..add(account);
    _currentUser = account;
    notifyListeners();
    await _persist();
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final index = _users.indexWhere(
      (user) => user.email.trim().toLowerCase() == normalizedEmail,
    );

    if (index == -1) {
      throw AppStateException('לא נמצאה הרשמה תואמת לדוא"ל שהוזן.');
    }

    final updatedUser = _users[index].copyWith(
      passwordHash: _hashPassword(newPassword),
    );
    _users = List<UserAccount>.from(_users)..[index] = updatedUser;
    if (_currentUser?.id == updatedUser.id) {
      _currentUser = updatedUser;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> updateCurrentUser({String? displayName, String? email}) async {
    if (_currentUser == null) {
      return;
    }

    final trimmedName = displayName?.trim();
    final normalizedEmail = email?.trim().toLowerCase();

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      final exists = _users.any(
        (user) =>
            user.email.trim().toLowerCase() == normalizedEmail &&
            user.id != _currentUser!.id,
      );
      if (exists) {
        throw AppStateException('כתובת הדוא"ל כבר בשימוש.');
      }
    }

    final updated = _currentUser!.copyWith(
      displayName:
          trimmedName != null && trimmedName.isNotEmpty
              ? trimmedName
              : _currentUser!.displayName,
      email:
          normalizedEmail != null && normalizedEmail.isNotEmpty
              ? normalizedEmail
              : _currentUser!.email,
    );

    final index = _users.indexWhere((user) => user.id == updated.id);
    if (index != -1) {
      _users = List<UserAccount>.from(_users)..[index] = updated;
    }

    _currentUser = updated;
    notifyListeners();
    await _persist();
  }

  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
    await _persist();
  }

  String addActivity(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw AppStateException('יש להזין שם פעילות.');
    }

    for (final activity in _activities) {
      if (activity.name.trim().toLowerCase() == trimmed.toLowerCase()) {
        return activity.id;
      }
    }

    final activity = ActivityDefinition(
      id: _uuid.v4(),
      name: trimmed,
      groups: const <GroupDefinition>[],
    );

    _activities = List<ActivityDefinition>.from(_activities)..add(activity);
    _activities.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    unawaited(_persist());
    return activity.id;
  }

  String addGroup(String activityId, String groupName) {
    final trimmed = groupName.trim();
    if (trimmed.isEmpty) {
      throw AppStateException('יש להזין שם קבוצה.');
    }

    final index = _activities.indexWhere(
      (activity) => activity.id == activityId,
    );
    if (index == -1) {
      throw AppStateException('הפעילות לא נמצאה.');
    }

    final activity = _activities[index];
    for (final group in activity.groups) {
      if (group.name.trim().toLowerCase() == trimmed.toLowerCase()) {
        return group.id;
      }
    }

    final newGroup = GroupDefinition(id: _uuid.v4(), name: trimmed);
    final updatedGroups = List<GroupDefinition>.from(activity.groups)
      ..add(newGroup);
    updatedGroups.sort((a, b) => a.name.compareTo(b.name));

    final updatedActivity = activity.copyWith(groups: updatedGroups);
    _activities = List<ActivityDefinition>.from(_activities)
      ..[index] = updatedActivity;
    notifyListeners();
    unawaited(_persist());
    return newGroup.id;
  }

  Student addStudent({
    required String fullName,
    required String activityId,
    required String groupId,
  }) {
    if (fullName.trim().isEmpty) {
      throw AppStateException('יש להזין שם חניך.');
    }

    if (activityById(activityId) == null) {
      throw AppStateException('הפעילות לא קיימת.');
    }

    if (groupById(activityId, groupId) == null) {
      throw AppStateException('הקבוצה לא קיימת.');
    }

    final student = Student(
      id: _uuid.v4(),
      fullName: fullName.trim(),
      activityId: activityId,
      groupId: groupId,
    );

    _students = List<Student>.from(_students)..add(student);
    notifyListeners();
    unawaited(_persist());
    return student;
  }

  void removeStudent(String studentId) {
    _students = List<Student>.from(_students)
      ..removeWhere((student) => student.id == studentId);
    _sessions =
        _sessions.map((session) {
          if (!session.statuses.containsKey(studentId)) {
            return session;
          }
          final updatedStatuses = Map<String, AttendanceStatus>.from(
            session.statuses,
          )..remove(studentId);
          return session.copyWith(statuses: updatedStatuses);
        }).toList();
    notifyListeners();
    unawaited(_persist());
  }

  ActivityDefinition? activityById(String activityId) {
    for (final activity in _activities) {
      if (activity.id == activityId) {
        return activity;
      }
    }
    return null;
  }

  GroupDefinition? groupById(String activityId, String groupId) {
    final activity = activityById(activityId);
    if (activity == null) {
      return null;
    }
    for (final group in activity.groups) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  List<ActivityDefinition> getSortedActivities() {
    final sorted = List<ActivityDefinition>.from(_activities);
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  List<GroupDefinition> groupsForActivity(String activityId) {
    final activity = activityById(activityId);
    if (activity == null) {
      return <GroupDefinition>[];
    }
    final groups = List<GroupDefinition>.from(activity.groups);
    groups.sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }

  List<Student> studentsFor(String activityId, String groupId) {
    final filtered =
        _students
            .where(
              (student) =>
                  student.activityId == activityId &&
                  student.groupId == groupId,
            )
            .toList();
    filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
    return filtered;
  }

  AttendanceSession? sessionFor(
    String activityId,
    String groupId,
    DateTime date,
  ) {
    final key = _dateKey(date);
    for (final session in _sessions) {
      if (session.activityId == activityId &&
          session.groupId == groupId &&
          _dateKey(session.date) == key) {
        return session;
      }
    }
    return null;
  }

  AttendanceSession? sessionById(String sessionId) {
    for (final session in _sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  AttendanceSession startSession(
    String activityId,
    String groupId,
    DateTime date,
  ) {
    final existing = sessionFor(activityId, groupId, date);
    if (existing != null) {
      return existing;
    }

    final normalizedDate = _normalizeDate(date);
    final activity = activityById(activityId);
    final group = groupById(activityId, groupId);

    final session = AttendanceSession(
      id: _uuid.v4(),
      activityId: activityId,
      groupId: groupId,
      activityName: activity?.name ?? '',
      groupName: group?.name ?? '',
      date: normalizedDate,
      isClosed: false,
      statuses: <String, AttendanceStatus>{},
    );

    _sessions = List<AttendanceSession>.from(_sessions)..add(session);
    notifyListeners();
    unawaited(_persist());
    return session;
  }

  void closeSession(String sessionId) {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) {
      return;
    }

    final updated = _sessions[index].copyWith(isClosed: true);
    _sessions = List<AttendanceSession>.from(_sessions)..[index] = updated;
    notifyListeners();
    unawaited(_persist());
  }

  void updateSessionNotes(String sessionId, {bool? isClosed}) {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) {
      return;
    }

    final session = _sessions[index];
    final updated = session.copyWith(isClosed: isClosed ?? session.isClosed);
    _sessions = List<AttendanceSession>.from(_sessions)..[index] = updated;
    notifyListeners();
    unawaited(_persist());
  }

  void markAttendance(
    String sessionId,
    String studentId,
    AttendanceStatus status,
  ) {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) {
      return;
    }

    final session = _sessions[index];
    final updatedStatuses = Map<String, AttendanceStatus>.from(session.statuses)
      ..[studentId] = status;
    final updatedSession = session.copyWith(statuses: updatedStatuses);

    _sessions = List<AttendanceSession>.from(_sessions)
      ..[index] = updatedSession;
    notifyListeners();
    unawaited(_persist());
  }

  void markAll(
    String sessionId,
    Iterable<String> studentIds,
    AttendanceStatus status,
  ) {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) {
      return;
    }

    final session = _sessions[index];
    final updatedStatuses = Map<String, AttendanceStatus>.from(
      session.statuses,
    );
    for (final id in studentIds) {
      updatedStatuses[id] = status;
    }
    final updatedSession = session.copyWith(statuses: updatedStatuses);
    _sessions = List<AttendanceSession>.from(_sessions)
      ..[index] = updatedSession;
    notifyListeners();
    unawaited(_persist());
  }

  List<AttendanceSession> sessionsForGroup(String activityId, String groupId) {
    final relevant =
        _sessions
            .where(
              (session) =>
                  session.activityId == activityId &&
                  session.groupId == groupId,
            )
            .toList();
    relevant.sort((a, b) => b.date.compareTo(a.date));
    return relevant;
  }

  List<AttendanceSession> sessionsInRange(
    String activityId,
    String groupId,
    DateTime start,
    DateTime end,
  ) {
    final normalizedStart = _normalizeDate(start);
    final normalizedEnd = _normalizeDate(end);

    return _sessions.where((session) {
        return session.activityId == activityId &&
            session.groupId == groupId &&
            !session.date.isBefore(normalizedStart) &&
            !session.date.isAfter(normalizedEnd);
      }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  AttendanceStatus statusForStudent(String sessionId, String studentId) {
    final session = sessionById(sessionId);
    if (session == null) {
      return AttendanceStatus.absent;
    }
    return session.statuses[studentId] ?? AttendanceStatus.absent;
  }

  UserAccount? _findUserById(String? id) {
    if (id == null) {
      return null;
    }
    for (final user in _users) {
      if (user.id == id) {
        return user;
      }
    }
    return null;
  }

  Future<void> _persist() async {
    if (!_initialized) {
      return;
    }

    if (_isSaving) {
      _pendingSave = true;
      return;
    }

    _isSaving = true;
    do {
      _pendingSave = false;
      final data = AppData(
        users: _users,
        currentUserId: _currentUser?.id,
        activities: _activities,
        students: _students,
        sessions: _sessions,
      );
      await _storage.save(data);
    } while (_pendingSave);
    _isSaving = false;
  }

  void _seedInitialData() {
    final danceActivity = ActivityDefinition(
      id: _uuid.v4(),
      name: 'חוג מחול מודרני',
      groups: <GroupDefinition>[
        GroupDefinition(id: _uuid.v4(), name: 'קבוצת בנות א׳'),
        GroupDefinition(id: _uuid.v4(), name: 'קבוצת בנות ב׳'),
      ],
    );

    final roboticsActivity = ActivityDefinition(
      id: _uuid.v4(),
      name: 'חוג רובוטיקה',
      groups: <GroupDefinition>[
        GroupDefinition(id: _uuid.v4(), name: 'קבוצת נוער'),
        GroupDefinition(id: _uuid.v4(), name: 'קבוצת ילדים'),
      ],
    );

    _activities = <ActivityDefinition>[danceActivity, roboticsActivity];

    _students = <Student>[
      Student(
        id: _uuid.v4(),
        fullName: 'שירה כהן',
        activityId: danceActivity.id,
        groupId: danceActivity.groups.first.id,
      ),
      Student(
        id: _uuid.v4(),
        fullName: 'ליאם מזרחי',
        activityId: danceActivity.id,
        groupId: danceActivity.groups.last.id,
      ),
      Student(
        id: _uuid.v4(),
        fullName: 'דניאל פרידמן',
        activityId: roboticsActivity.id,
        groupId: roboticsActivity.groups.first.id,
      ),
      Student(
        id: _uuid.v4(),
        fullName: 'רוני עמר',
        activityId: roboticsActivity.id,
        groupId: roboticsActivity.groups.last.id,
      ),
    ];
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    return _dateFormatter.format(_normalizeDate(date));
  }
}
