import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../i18n/locale_controller.dart';

/// Barre de saisie de message partagée entre les conversations privées et
/// les fils de canal — même langage visuel partout dans l'app (§ retour
/// utilisateur « la messagerie doit être vraiment cool ») : champ en
/// pilule, bouton d'envoi circulaire séparé.
class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onEnvoyer,
    this.hintText,
    this.onChanged,
    this.onJoindreFichier,
  });

  final TextEditingController controller;
  final VoidCallback onEnvoyer;

  /// `null` retombe sur le placeholder traduit par défaut.
  final String? hintText;

  /// Appelé à chaque frappe — sert notamment à signaler « en train
  /// d'écrire » à l'interlocuteur. `null` si ce signal n'a pas de sens ici
  /// (ex. réponse dans un canal).
  final ValueChanged<String>? onChanged;

  /// Bouton trombone pour joindre une photo ou un PDF — `null` masque le
  /// bouton (toutes les surfaces de messagerie n'en ont pas besoin).
  final VoidCallback? onJoindreFichier;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onJoindreFichier != null)
              IconButton(
                onPressed: onJoindreFichier,
                tooltip: tr(context, 'Joindre une photo ou un PDF'),
                icon: Icon(Icons.attach_file_rounded, color: t.textMuted),
              ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: t.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.border),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: hintText ?? tr(context, 'Écrire un message'),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => onEnvoyer(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onEnvoyer,
              customBorder: const CircleBorder(),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: UniverseColors.brandGradient,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
