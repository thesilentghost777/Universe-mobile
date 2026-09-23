/// Garde un suffixe très court (« I », « L3 ») collé au mot d'avant.
///
/// Sans ça, « Université de Yaoundé I » se coupe et laisse le « I » seul
/// sur la ligne suivante dès que la colonne est étroite.
String eviterMotOrphelin(String texte) {
  final parts = texte.trim().split(RegExp(r'\s+'));
  if (parts.length < 2 || parts.last.length > 2) return texte.trim();
  final last = parts.removeLast();
  return '${parts.join(' ')}\u00A0$last';
}
