import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_definition.dart';
import '../models/attendance_session.dart';
import '../models/student.dart';
import '../state/app_state.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String? _selectedActivityId;
  String? _selectedGroupId;
  DateTime _selectedDate = DateTime.now();
  String? _currentSessionId;
  bool _didInit = false;
  bool _isEditingPrevious = false;

  final DateFormat _headerFormatter = DateFormat('dd.MM.yyyy', 'he');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) {
      return;
    }

    final appState = context.read<AppState>();
    final activities = appState.getSortedActivities();
    if (activities.isNotEmpty) {
      _selectedActivityId ??= activities.first.id;
      final groups = appState.groupsForActivity(_selectedActivityId!);
      if (groups.isNotEmpty) {
        _selectedGroupId ??= groups.first.id;
      }
    }
    _loadSessionForSelection();
    _didInit = true;
  }

  void _loadSessionForSelection() {
    if (_selectedActivityId == null || _selectedGroupId == null) {
      setState(() {
        _currentSessionId = null;
        _isEditingPrevious = false;
      });
      return;
    }

    final appState = context.read<AppState>();
    final session = appState.sessionFor(
      _selectedActivityId!,
      _selectedGroupId!,
      _selectedDate,
    );

    setState(() {
      _currentSessionId = session?.id;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('he'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isEditingPrevious = false;
      });
      _loadSessionForSelection();
    }
  }

  Future<void> _startNewSession() async {
    if (_selectedActivityId == null || _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לבחור פעילות וקבוצה לפני פתיחת מפגש.'),
        ),
      );
      return;
    }

    final session = context.read<AppState>().startSession(
      _selectedActivityId!,
      _selectedGroupId!,
      _selectedDate,
    );
    setState(() {
      _currentSessionId = session.id;
      _isEditingPrevious = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('מפגש חדש נפתח בהצלחה.')));
  }

  void _markAttendance(String studentId, AttendanceStatus status) {
    if (_currentSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש לפתוח מפגש לפני סימון נוכחות.')),
      );
      return;
    }
    context.read<AppState>().markAttendance(
      _currentSessionId!,
      studentId,
      status,
    );
  }

  void _markAll(List<String> studentIds, AttendanceStatus status) {
    if (_currentSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש לפתוח מפגש לפני סימון נוכחות.')),
      );
      return;
    }
    context.read<AppState>().markAll(_currentSessionId!, studentIds, status);
    final label =
        status == AttendanceStatus.present
            ? 'כל החניכים סומנו כנוכחים.'
            : 'כל החניכים סומנו כחסרים.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Future<void> _showPreviousSessions() async {
    if (_selectedActivityId == null || _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('בחרו פעילות וקבוצה לצפייה במפגשים קודמים.'),
        ),
      );
      return;
    }
    final appState = context.read<AppState>();
    final sessions = appState.sessionsForGroup(
      _selectedActivityId!,
      _selectedGroupId!,
    );
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא נמצאו מפגשים קודמים לקבוצה זו.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final dateLabel = _headerFormatter.format(session.date);
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: Colors.grey[100],
                leading: const Icon(Icons.history),
                title: Text(session.activityName, textAlign: TextAlign.right),
                subtitle: Text(
                  '${session.groupName} • $dateLabel',
                  textAlign: TextAlign.right,
                ),
                onTap: () {
                  setState(() {
                    _currentSessionId = session.id;
                    _selectedDate = session.date;
                    _isEditingPrevious = true;
                  });
                  Navigator.of(context).pop();
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: sessions.length,
          ),
        );
      },
    );
  }

  Future<void> _openAddActivityDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return _SingleFieldDialog(
          title: 'פעילות חדשה',
          hintText: 'שם הפעילות',
          controller: controller,
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final id = context.read<AppState>().addActivity(result.trim());
        setState(() {
          _selectedActivityId = id;
          _selectedGroupId = null;
          _isEditingPrevious = false;
        });
        _loadSessionForSelection();
      } on AppStateException catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openAddGroupDialog() async {
    if (_selectedActivityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש לבחור פעילות לפני יצירת קבוצה.')),
      );
      return;
    }
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return _SingleFieldDialog(
          title: 'קבוצה חדשה',
          hintText: 'שם הקבוצה',
          controller: controller,
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final id = context.read<AppState>().addGroup(
          _selectedActivityId!,
          result.trim(),
        );
        setState(() {
          _selectedGroupId = id;
          _isEditingPrevious = false;
        });
        _loadSessionForSelection();
      } on AppStateException catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openAddStudentDialog() async {
    if (_selectedActivityId == null || _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לבחור פעילות וקבוצה לפני הוספת חניך.'),
        ),
      );
      return;
    }
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return _SingleFieldDialog(
          title: 'הוספת חניך',
          hintText: 'שם החניך/ה',
          controller: controller,
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        context.read<AppState>().addStudent(
          fullName: result.trim(),
          activityId: _selectedActivityId!,
          groupId: _selectedGroupId!,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('החניך נוסף בהצלחה.')));
      } on AppStateException catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  AttendanceSession? _currentSession(AppState state) {
    if (_currentSessionId != null) {
      final session = state.sessionById(_currentSessionId!);
      if (session != null) {
        return session;
      }
    }
    if (_selectedActivityId != null && _selectedGroupId != null) {
      return state.sessionFor(
        _selectedActivityId!,
        _selectedGroupId!,
        _selectedDate,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activities = appState.getSortedActivities();
    final groups =
        _selectedActivityId != null
            ? appState.groupsForActivity(_selectedActivityId!)
            : <GroupDefinition>[];
    final students =
        (_selectedActivityId != null && _selectedGroupId != null)
            ? appState.studentsFor(_selectedActivityId!, _selectedGroupId!)
            : <Student>[];
    final session = _currentSession(appState);

    final selectedStudentIds = students.map((student) => student.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ניהול נוכחות'),
        actions: [
          PopupMenuButton<_AttendanceMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _AttendanceMenuAction.addActivity:
                  _openAddActivityDialog();
                  break;
                case _AttendanceMenuAction.addGroup:
                  _openAddGroupDialog();
                  break;
                case _AttendanceMenuAction.addStudent:
                  _openAddStudentDialog();
                  break;
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: _AttendanceMenuAction.addActivity,
                    child: Text('הוספת פעילות'),
                  ),
                  PopupMenuItem(
                    value: _AttendanceMenuAction.addGroup,
                    child: Text('הוספת קבוצה'),
                  ),
                  PopupMenuItem(
                    value: _AttendanceMenuAction.addStudent,
                    child: Text('הוספת חניך'),
                  ),
                ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: _selectedActivityId,
                            decoration: const InputDecoration(
                              labelText: 'פעילות',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                activities
                                    .map(
                                      (activity) => DropdownMenuItem(
                                        value: activity.id,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(activity.name),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedActivityId = value;
                                _selectedGroupId = null;
                                _isEditingPrevious = false;
                              });
                              if (value != null) {
                                final updatedGroups = appState
                                    .groupsForActivity(value);
                                if (updatedGroups.isNotEmpty) {
                                  setState(() {
                                    _selectedGroupId = updatedGroups.first.id;
                                  });
                                }
                              }
                              _loadSessionForSelection();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            value: _selectedGroupId,
                            decoration: const InputDecoration(
                              labelText: 'קבוצה',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                groups
                                    .map(
                                      (group) => DropdownMenuItem(
                                        value: group.id,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(group.name),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedGroupId = value;
                                _isEditingPrevious = false;
                              });
                              _loadSessionForSelection();
                            },
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'תאריך המפגש',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _headerFormatter.format(_selectedDate),
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _selectDate,
                                  icon: const Icon(Icons.event),
                                  label: const Text('בחירת תאריך'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.end,
                          children: [
                            FilledButton.icon(
                              onPressed: _startNewSession,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('פתיחת מפגש'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  selectedStudentIds.isEmpty
                                      ? null
                                      : () => _markAll(
                                        selectedStudentIds,
                                        AttendanceStatus.present,
                                      ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('סימון כולם נוכחים'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  selectedStudentIds.isEmpty
                                      ? null
                                      : () => _markAll(
                                        selectedStudentIds,
                                        AttendanceStatus.absent,
                                      ),
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('סימון כולם חסרים'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _showPreviousSessions,
                            icon: const Icon(Icons.history),
                            label: const Text('מפגשים קודמים'),
                          ),
                        ),
                      ],
                    ),
                    if (_isEditingPrevious)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.edit, size: 18),
                              label: const Text('עריכת מפגש קודם'),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime.now();
                                  _isEditingPrevious = false;
                                });
                                _loadSessionForSelection();
                              },
                              child: const Text('חזרה למפגש היום'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedActivityId == null || _selectedGroupId == null)
              Expanded(
                child: Center(
                  child: Text(
                    'בחרו פעילות וקבוצה כדי להתחיל לסמן נוכחות.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (students.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'לא הוזנו חניכים לקבוצה זו עדיין.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _openAddStudentDialog,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('הוספת חניך ראשון'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final status =
                        session?.statuses[student.id] ??
                        AttendanceStatus.absent;
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              student.fullName,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<AttendanceStatus>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: AttendanceStatus.present,
                                  label: _SegmentLabel(
                                    text: 'נוכח',
                                    icon: Icons.check,
                                  ),
                                ),
                                ButtonSegment(
                                  value: AttendanceStatus.absent,
                                  label: _SegmentLabel(
                                    text: 'חסר',
                                    icon: Icons.close,
                                  ),
                                ),
                              ],
                              selected: <AttendanceStatus>{status},
                              onSelectionChanged:
                                  _currentSessionId == null
                                      ? null
                                      : (newSelection) {
                                        final choice = newSelection.first;
                                        _markAttendance(student.id, choice);
                                      },
                              style: ButtonStyle(
                                padding: MaterialStateProperty.all(
                                  const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStudentDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('הוספת חניך'),
      ),
    );
  }
}

enum _AttendanceMenuAction { addActivity, addGroup, addStudent }

class _SingleFieldDialog extends StatelessWidget {
  const _SingleFieldDialog({
    required this.title,
    required this.hintText,
    required this.controller,
  });

  final String title;
  final String hintText;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.right),
      content: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        decoration: InputDecoration(hintText: hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('שמירה'),
        ),
      ],
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: theme.textTheme.titleSmall),
        const SizedBox(width: 6),
        Icon(icon, size: 18),
      ],
    );
  }
}
