/// Formatage de date/heure — les mots fixes passent par [tr] pour rester
/// bilingues (voir `core/i18n/locale_controller.dart`) ; le reste (mois,
/// jours de semaine) est traduit directement ici, faute d'appui sur une
/// dépendance de locale `intl`.
library;

import 'package:flutter/widgets.dart';

import '../i18n/locale_controller.dart';

bool memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String heureCourte(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

const moisLettres = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août',
  'septembre', 'octobre', 'novembre', 'décembre',
];

const _moisLettresEn = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
];

String _mois(BuildContext context, int index) =>
    LocaleScope.of(context) ? _moisLettresEn[index] : moisLettres[index];

/// Libellé d'un séparateur de date dans un fil de messages.
String libelleJour(BuildContext context, DateTime d) {
  final maintenant = DateTime.now();
  final aujourdHui = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final jour = DateTime(d.year, d.month, d.day);
  final ecart = aujourdHui.difference(jour).inDays;
  if (ecart == 0) return tr(context, 'Aujourd\'hui');
  if (ecart == 1) return tr(context, 'Hier');
  return '${d.day} ${_mois(context, d.month - 1)}'
      '${d.year != maintenant.year ? ' ${d.year}' : ''}';
}

/// Temps écoulé, format court et lisible façon plateforme vidéo
/// ("il y a 2 j").
String ilYA(BuildContext context, DateTime date) {
  final diff = DateTime.now().difference(date);
  final en = LocaleScope.of(context);
  if (diff.inDays >= 365) {
    final ans = (diff.inDays / 365).floor();
    return en
        ? '$ans ${ans > 1 ? 'years' : 'year'} ago'
        : 'il y a $ans an${ans > 1 ? 's' : ''}';
  }
  if (diff.inDays >= 30) {
    final mois = (diff.inDays / 30).floor();
    return en ? '$mois mo ago' : 'il y a $mois mois';
  }
  if (diff.inDays >= 1) {
    return en ? '${diff.inDays} d ago' : 'il y a ${diff.inDays} j';
  }
  if (diff.inHours >= 1) {
    return en ? '${diff.inHours} h ago' : 'il y a ${diff.inHours} h';
  }
  if (diff.inMinutes >= 1) {
    return en ? '${diff.inMinutes} min ago' : 'il y a ${diff.inMinutes} min';
  }
  return en ? 'just now' : 'à l\'instant';
}

/// Heure/jour affiché dans une liste (style WhatsApp) : l'heure si
/// aujourd'hui, le jour de la semaine si cette semaine, une date courte
/// sinon.
String heureListe(BuildContext context, DateTime d) {
  final maintenant = DateTime.now();
  final aujourdHui = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final jour = DateTime(d.year, d.month, d.day);
  final ecart = aujourdHui.difference(jour).inDays;
  if (ecart == 0) return heureCourte(d);
  if (ecart == 1) return tr(context, 'Hier');
  if (ecart < 7) {
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const joursEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return LocaleScope.of(context) ? joursEn[d.weekday - 1] : jours[d.weekday - 1];
  }
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
