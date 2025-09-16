import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  static final Uri _matnasScheduleUri = Uri.parse(
    'https://arad.matnasim.co.il/',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('מערכת שעות וחומרים')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'קישורים מרכזיים',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'כאן תוכלו להגיע במהירות ללוח החוגים ולהרשמות של מתנ"ס ערד. מומלץ לשמור את הקישור ולבדוק עדכונים שוטפים.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _openLink(_matnasScheduleUri, context),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('פתיחת אתר החוגים של מתנ"ס ערד'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'טיפ לניהול מקומי',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ניתן לשמור קבצי מערכת שעות מקומיים בתיקיית "מסמכים" של היישום ולהוסיף אותם לפגישות באמצעות דו"חות PDF. רצוי לעדכן את הלוחות מדי תחילת מחזור.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(Uri uri, BuildContext context) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן היה לפתוח את הקישור.')),
        );
      }
    }
  }
}
