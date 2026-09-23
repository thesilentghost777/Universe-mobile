import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../utils/date_format.dart';

/// Pastille centrée « Aujourd'hui / Hier / 12 septembre » entre deux jours
/// dans un fil de messages — partagée entre conversations et canaux.
class DateSeparatorPill extends StatelessWidget {
  const DateSeparatorPill({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: t.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: Text(
            libelleJour(context, date),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
