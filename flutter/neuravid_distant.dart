// NEURAVID — ouvrir la référence publiée (site) dans l'application, avec la copie embarquée en secours.
//
// ⚠️ À LIRE : ce fichier n'a PAS été compilé ni lancé (aucun SDK Flutter dans l'espace où il a été écrit).
// Il suit l'API de flutter_inappwebview 6.x (celle de ton APK actuel). Afaq : relis-le, adapte les noms
// (ta session, ton écran) et teste-le sur un téléphone avant de le publier.
//
// Principe :
//  1. l'application ouvre https://app.neuravid.com/index.html : toujours la dernière version publiée ;
//  2. les modules s'ouvrent entre eux tout seuls (NV_MODULES_BASE = l'adresse du site) ;
//  3. sans réseau, la même référence copiée dans l'APK (assets/web/) prend le relais ;
//  4. l'adresse du serveur vient de nv-config.js (un seul endroit) ; l'application pose seulement
//     le jeton, la personne et la langue au démarrage de chaque page.
//
// pubspec.yaml — la copie de secours (copie exacte du dossier web/ de la référence) :
//   flutter:
//     assets:
//       - assets/web/
//       - assets/web/icones/
//       - assets/web/cadeaux3d/
//       - assets/web/ia/

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// La référence publiée (site). Une seule adresse, à la racine du domaine (La Forge cherche son moteur en « /ia/ »).
const String kSite = 'https://app.neuravid.com/';

/// La même référence, embarquée dans l'APK pour le hors-connexion.
const String kSecoursAsset = 'assets/web/';
const String kSecoursBase = 'file:///android_asset/flutter_assets/assets/web/';

/// À brancher sur ta session (connexion, langue choisie).
class NvSession {
  static String? jeton;                      // le jeton du serveur NEURAVID
  static Map<String, dynamic>? utilisateur;  // {id, handle, prenom, age, iso, ...}
  static String langue = 'fr';
}

class NeuravidEcran extends StatefulWidget {
  const NeuravidEcran({super.key, this.page = 'index.html'});

  /// La page de départ : 'index.html' (l'accueil), ou un module : 'NV_MODULE_Live.html', 'NV_MODULE_Iris.html'…
  final String page;

  @override
  State<NeuravidEcran> createState() => _NeuravidEcranState();
}

class _NeuravidEcranState extends State<NeuravidEcran> {
  InAppWebViewController? _controleur;
  bool _enSecours = false;

  /// Posé AVANT tout script de la page. Ne pose jamais NV_API_BASE ici : nv-config.js s'en charge
  /// (sinon le site et l'application pourraient pointer vers deux serveurs différents).
  UserScript _depart(String base) => UserScript(
        source: '''
window.NV_MODULES_BASE = ${jsonEncode(base)};
window.NV_TOKEN = ${jsonEncode(NvSession.jeton)};
window.NV_USER = ${jsonEncode(NvSession.utilisateur)};
window.NV_LANG = ${jsonEncode(NvSession.langue)};
''',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      );

  Future<void> _passerEnSecours(InAppWebViewController c) async {
    if (_enSecours) return;
    _enSecours = true;
    await c.removeAllUserScripts();
    await c.addUserScript(userScript: _depart(kSecoursBase));
    await c.loadFile(assetFilePath: kSecoursAsset + widget.page);
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(kSite + widget.page)),
      initialUserScripts: UnmodifiableListView<UserScript>([_depart(kSite)]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false, // le son des vidéos démarre seul (règle de NEURAVID)
        allowsInlineMediaPlayback: true,
        cacheMode: CacheMode.LOAD_DEFAULT,       // le serveur dit quand une page a changé (ETag / no-cache)
        allowFileAccessFromFileURLs: true,       // copie de secours : les modules s'ouvrent entre eux en file://
        allowUniversalAccessFromFileURLs: true,
        useHybridComposition: true,
      ),
      onWebViewCreated: (c) {
        _controleur = c;
        // Les événements des modules (ouvrir un module, confirmer un geste, signalement sans serveur…)
        c.addJavaScriptHandler(
          handlerName: 'nvEvent',
          callback: (args) {
            // args[0] = {source:'neuravid', module, type, payload}
            // Exemple : type 'report_submit' → envoyer au serveur, puis répondre :
            //   c.evaluateJavascript(source: 'window.NVReportConfirm(${jsonEncode({...})})');
            return null;
          },
        );
      },
      onReceivedError: (c, requete, erreur) async {
        // Seulement si la PAGE elle-même ne se charge pas (pas une image ou un appel au serveur).
        if (requete.isForMainFrame ?? false) await _passerEnSecours(c);
      },
    );
  }
}

// Ouvrir un module depuis Flutter :
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const NeuravidEcran(page: 'NV_MODULE_Recolte.html')));
// Le lecteur principal : 'NV_MODULE_Iris.html' (l'id « Player » mène aussi à Iris).
// Inutile de tenir une liste des modules dans le code Dart : chaque module ouvre les autres par
// NV_MODULES_BASE + 'NV_MODULE_<id>.html'. Un nouveau module publié est donc disponible sans nouvel APK.
