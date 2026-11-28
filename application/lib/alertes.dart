// NEURAVID — les alertes du téléphone avec Firebase (v131, 28 novembre 2026).
// Toujours compilé. Sans les variables GitHub FIREBASE_* (valeurs du projet Firebase), Firebase n'est jamais démarré :
// aucune question, aucune alerte, rien d'autre ne change.
// iPhone : Firebase passe par APNs (clé APNs envoyée par Karamo dans la console Firebase). Android : Firebase directement.
// Le serveur (socle) envoie un titre et un texte visibles, sans rien de privé ; toucher l'alerte ouvre la bonne page.
// La permission n'est demandée que quand une personne est connectée (la page appelle nvJetonAppareil avec une session).
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _kProjet = String.fromEnvironment('NV_FIREBASE_PROJET');
const String _kExpediteur = String.fromEnvironment('NV_FIREBASE_EXPEDITEUR');
const String _kCleAndroid = String.fromEnvironment('NV_FIREBASE_CLE_ANDROID');
const String _kAppliAndroid = String.fromEnvironment('NV_FIREBASE_APPLI_ANDROID');
const String _kCleIos = String.fromEnvironment('NV_FIREBASE_CLE_IOS');
const String _kAppliIos = String.fromEnvironment('NV_FIREBASE_APPLI_IOS');

class Alertes {
  Alertes._();
  static final Alertes instance = Alertes._();
  InAppWebViewController? controleur;
  bool _pret = false;
  bool get actives => _pret;
  void Function(String chemin)? _ouvrir;

  FirebaseOptions? get _options {
    final ios = Platform.isIOS;
    final cle = ios ? _kCleIos : _kCleAndroid, appli = ios ? _kAppliIos : _kAppliAndroid;
    if (_kProjet.isEmpty || _kExpediteur.isEmpty || cle.isEmpty || appli.isEmpty) return null;
    return FirebaseOptions(apiKey: cle, appId: appli, messagingSenderId: _kExpediteur, projectId: _kProjet,
        iosBundleId: ios ? 'com.neuravid.app' : null);
  }

  /// La page à ouvrir pour une alerte touchée (chemin relatif au site).
  static String cible(Map<String, dynamic> d) {
    final type = (d['type'] ?? '').toString();
    final appel = (d['appel'] ?? '').toString();
    if (type == 'appel_entrant' && RegExp(r'^[A-Za-z0-9_-]{3,80}$').hasMatch(appel)) {
      return 'NV_MODULE_CallUniverse.html#appel=' + Uri.encodeComponent(appel);
    }
    final id = (d['id'] ?? '').toString();
    return 'NV_MODULE_Notifications.html' + (id.isNotEmpty && id.length <= 80 ? '#id=' + Uri.encodeComponent(id) : '');
  }

  Future<void> demarrer(void Function(String chemin) ouvrir) async {
    _ouvrir = ouvrir;
    final o = _options;
    if (o == null) return;
    try {
      await Firebase.initializeApp(options: o);
      final m = FirebaseMessaging.instance;
      // l'application ouverte : l'alerte se montre quand même (comme les autres applications)
      await m.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessageOpenedApp.listen((r) => _ouvrir?.call(cible(r.data)));
      final debut = await m.getInitialMessage();
      if (debut != null) unawaited(_plusTard(cible(debut.data)));
      m.onTokenRefresh.listen((t) => _donner(t));
      _pret = true;
    } catch (_) {
      _pret = false; // sans Firebase : pas d'alertes, rien d'autre ne change
    }
  }

  // l'application vient d'être ouverte par une alerte : attendre que la page soit là, puis ouvrir la bonne
  Future<void> _plusTard(String chemin) async {
    for (var i = 0; i < 40 && controleur == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _ouvrir?.call(chemin);
  }

  void _donner(String t) {
    final c = controleur;
    if (c == null) return;
    final pf = Platform.isIOS ? 'ios' : 'android';
    c.evaluateJavascript(source: 'window.NVAppareilJeton && window.NVAppareilJeton(' + _js(t) + ", '" + pf + "')");
  }

  static String _js(String s) => "'" + s.replaceAll('\\', '\\\\').replaceAll("'", "\\'") + "'";

  /// Appelé par la page (nvJetonAppareil) quand une personne est connectée : la question du téléphone, puis le jeton.
  Future<Map<String, dynamic>?> jeton(List<dynamic> args) async {
    if (!_pret) return null;
    try {
      final m = FirebaseMessaging.instance;
      final r = await m.requestPermission(alert: true, badge: true, sound: true);
      if (r.authorizationStatus == AuthorizationStatus.denied) return null;
      if (Platform.isIOS) {
        String? apns;
        for (var i = 0; i < 20 && apns == null; i++) {
          apns = await m.getAPNSToken();
          if (apns == null) await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (apns == null) return null;
      }
      final t = await m.getToken();
      if (t == null || t.length < 20) return null;
      return {'jeton': t, 'plateforme': Platform.isIOS ? 'ios' : 'android'};
    } catch (_) {
      return null;
    }
  }
}
