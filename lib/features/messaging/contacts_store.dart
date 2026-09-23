import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_state.dart';
import '../../core/demo/demo_content.dart';

/// Une personne croisée dans l'application.
class Contact {
  const Contact({required this.id, required this.nom, this.rang, this.photoUrl});

  final String id;
  final String nom;

  /// Rang exact, nécessaire pour appliquer la matrice de messagerie.
  /// `null` quand le serveur ne l'a pas renvoyé.
  final String? rang;

  /// `null` tant que le back ne renvoie pas de photo (voir
  /// `UserProfile.photoUrl`) — l'avatar retombe alors sur l'initiale.
  final String? photoUrl;

  Map<String, dynamic> toJson() =>
      {'id': id, 'nom': nom, 'rang': rang, 'photoUrl': photoUrl};

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'] as String,
        nom: j['nom'] as String? ?? 'Utilisateur',
        rang: j['rang'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
}

/// Carnet d'adresses local.
///
/// Le cahier des charges ne prévoit **aucune route de recherche
/// d'utilisateurs** : il n'existe que `GET /utilisateurs/:id`, qui suppose de
/// déjà connaître l'identifiant. Impossible, donc, de proposer un annuaire.
///
/// À la place, l'application retient les personnes que l'utilisateur a
/// réellement croisées — les auteurs des messages qu'il lit dans les fils de
/// discussion. C'est le chemin naturel : on lit une réponse utile, on veut
/// écrire à son auteur.
///
/// Un annuaire complet demandera un endpoint de recherche côté serveur.
final contactsProvider =
    NotifierProvider<ContactsStore, List<Contact>>(ContactsStore.new);

class ContactsStore extends Notifier<List<Contact>> {
  static const _key = 'universe_contacts_recents';
  static const _max = 60;

  /// `true` pour un compte du Mode Test : le carnet est alors pré-rempli
  /// (pour tester « Nouveau message » tout de suite) et stocké sous une clé
  /// distincte — un vrai compte ne voit jamais les contacts fictifs.
  bool _demo = false;

  String get _cle => _demo ? '${_key}_demo' : _key;

  @override
  List<Contact> build() {
    // Rebâti à chaque changement de compte, pour recharger le bon carnet.
    _demo = estCompteDemo(
      ref.watch(authNotifierProvider.select((s) => s.user?.id)),
    );
    _restaurer();
    return _demo
        ? DemoContent.contactsCarnet
            .map((c) => Contact.fromJson(Map<String, dynamic>.from(c)))
            .toList()
        : const [];
  }

  Future<void> _restaurer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut == null) return;
      state = (jsonDecode(brut) as List)
          .map((e) => Contact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Carnet illisible : on repart à vide, sans bloquer l'app.
    }
  }

  Future<void> _persister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cle,
        jsonEncode(state.take(_max).map((c) => c.toJson()).toList()),
      );
    } catch (_) {
      // Echec d'écriture : le carnet reste en mémoire pour la session.
    }
  }

  /// Enregistre une personne croisée. Le plus récent remonte en tête.
  Future<void> memoriser(Contact contact) async {
    if (contact.id.isEmpty || contact.nom.trim().isEmpty) return;
    final autres = state.where((c) => c.id != contact.id).toList();
    state = [contact, ...autres].take(_max).toList();
    await _persister();
  }

  /// Enregistre plusieurs personnes d'un coup (à l'ouverture d'un fil).
  Future<void> memoriserPlusieurs(Iterable<Contact> contacts) async {
    var modifie = false;
    var liste = [...state];
    for (final c in contacts) {
      if (c.id.isEmpty || c.nom.trim().isEmpty) continue;
      if (liste.any((e) => e.id == c.id && e.rang == c.rang)) continue;
      liste = [c, ...liste.where((e) => e.id != c.id)];
      modifie = true;
    }
    if (!modifie) return;
    state = liste.take(_max).toList();
    await _persister();
  }

  Future<void> oublier(String id) async {
    state = state.where((c) => c.id != id).toList();
    await _persister();
  }
}

/// Comptes bloqués — quelqu'un qui écrit pour la première fois (via son
/// identifiant) peut être accepté ou bloqué par le destinataire avant que la
/// conversation ne s'ouvre vraiment.
final blockedContactsProvider =
    NotifierProvider<BlockedContactsStore, List<Contact>>(
  BlockedContactsStore.new,
);

class BlockedContactsStore extends Notifier<List<Contact>> {
  static const _key = 'universe_contacts_bloques';

  /// Même isolation que [ContactsStore] : les blocages faits pendant une
  /// session du Mode Test ne touchent jamais la liste d'un vrai compte.
  bool _demo = false;

  String get _cle => _demo ? '${_key}_demo' : _key;

  @override
  List<Contact> build() {
    _demo = estCompteDemo(
      ref.watch(authNotifierProvider.select((s) => s.user?.id)),
    );
    _restaurer();
    return const [];
  }

  Future<void> _restaurer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut == null) return;
      state = (jsonDecode(brut) as List)
          .map((e) => Contact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}
  }

  Future<void> _persister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cle,
        jsonEncode(state.map((c) => c.toJson()).toList()),
      );
    } catch (_) {}
  }

  bool estBloque(String id) => state.any((c) => c.id == id);

  Future<void> bloquer(Contact contact) async {
    if (estBloque(contact.id)) return;
    state = [contact, ...state];
    await _persister();
  }

  Future<void> debloquer(String id) async {
    state = state.where((c) => c.id != id).toList();
    await _persister();
  }
}
