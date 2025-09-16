import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'attendance_page.dart';
import 'profile_page.dart';
import 'reports_page.dart';
import 'schedule_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final theme = Theme.of(context);

    final actions = <_DashboardAction>[
      _DashboardAction(
        title: 'ניהול נוכחות',
        subtitle: 'יצירת מפגשים, סימון חניכים וניהול עבר',
        icon: Icons.assignment_turned_in_outlined,
        destination: const AttendancePage(),
      ),
      _DashboardAction(
        title: 'דו"חות וייצוא',
        subtitle: 'הפקת קבצי Excel / PDF וניתוח נוכחות',
        icon: Icons.analytics_outlined,
        destination: const AttendanceReportPage(),
      ),
      _DashboardAction(
        title: 'פרופיל אישי',
        subtitle: 'עדכון פרטי איש קשר ותמונת פרופיל',
        icon: Icons.person_outline,
        destination: const ProfilePage(),
      ),
      _DashboardAction(
        title: 'מערכת שעות',
        subtitle: 'צפייה בקישורי חוגים ומסמכי מערכת',
        icon: Icons.schedule_outlined,
        destination: const SchedulePage(),
      ),
    ];

    final latestSessions = List.of(appState.sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final sessionPreview = latestSessions.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('מרכז שליטה'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'התנתקות',
            onPressed: () => context.read<AppState>().signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 600
                    ? 2
                    : 1;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WelcomeBanner(userName: user?.displayName ?? 'צוות מתנ"ס'),
                  const SizedBox(height: 24),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: actions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio:
                          crossAxisCount == 1
                              ? 1.65
                              : crossAxisCount == 2
                              ? 1.3
                              : 1.15,
                    ),
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      return _DashboardCard(
                        action: action,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => action.destination,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'מפגשים אחרונים',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 12),
                          if (sessionPreview.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'טרם נרשמו מפגשי נוכחות. התחילו במעבר למסך הנוכחות.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            )
                          else
                            ...sessionPreview.map((session) {
                              final formattedDate = DateFormat(
                                'dd.MM.yyyy',
                                'he',
                              ).format(session.date);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.12),
                                  foregroundColor: theme.colorScheme.primary,
                                  child: const Icon(Icons.event_available),
                                ),
                                title: Text(
                                  session.activityName.isEmpty
                                      ? 'פעילות'
                                      : session.activityName,
                                  textAlign: TextAlign.right,
                                ),
                                subtitle: Text(
                                  '${session.groupName} • $formattedDate',
                                  textAlign: TextAlign.right,
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardAction {
  _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destination,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget destination;
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.action, required this.onTap});

  final _DashboardAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.12),
              theme.colorScheme.secondaryContainer.withOpacity(0.4),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  action.icon,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    action.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7285), Color(0xFF1AA6B7)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'שלום $userName!',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Text(
            'המשיכו לעדכן נוכחות, לייצא דו"חות ולנהל את החוגים של מתנ"ס ערד במקום אחד.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
