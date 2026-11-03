// NEURAVID Aperçu — l'application de démonstration complète (Android).
//
// Elle ouvre la démonstration publiée sur le site (la même que l'artifact de Karamo, avec le repère « Aperçu »),
// donc TOUS les modules et TOUTES les fonctions, toujours dans leur dernière version publiée.
// Sans réseau, la copie de web/ embarquée dans l'APK prend le relais.
// Construite automatiquement par GitHub (.github/workflows/apk-demo.yml) — Afaq : c'est une base de travail,
// pas l'application de production (paquet com.neuravid.apercu, signature de démonstration).
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

const String kSite = 'https://karamo655.github.io/neuravid-app/';
const String kDepart = 'demo.html';
const String kSecoursAsset = 'assets/web/';
const String kSecoursBase = 'file:///android_asset/flutter_assets/assets/web/';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0B0720),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0B0720),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const NeuravidApercu());
}

class NeuravidApercu extends StatelessWidget {
  const NeuravidApercu({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEURAVID Aperçu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF0B0720)),
      home: const EcranNeuravid(),
    );
  }
}

class EcranNeuravid extends StatefulWidget {
  const EcranNeuravid({super.key});

  @override
  State<EcranNeuravid> createState() => _EcranNeuravidState();
}

class _EcranNeuravidState extends State<EcranNeuravid> {
  InAppWebViewController? _controleur;
  bool _enSecours = false;

  /// Posé avant tout script de chaque page : les modules s'ouvrent entre eux, la langue du téléphone.
  /// NV_APERCU (3 nov. 2026) : chaque module éteint l'aperçu quand il voit « window.flutter_inappwebview » (l'application
  /// de production). Cette APK est l'aperçu : elle le dit, et les modules gardent leurs exemples (repère « Aperçu »).
  /// L'application de production ne pose JAMAIS ce drapeau.
  UserScript _depart(String base) {
    final langue = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return UserScript(
      source: '''
window.NV_MODULES_BASE = ${jsonEncode(base)};
window.NV_APERCU = true;
if(!window.NV_LANG) window.NV_LANG = ${jsonEncode(langue)};
''',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
  }

  Future<void> _passerEnSecours(InAppWebViewController c) async {
    if (_enSecours) return;
    _enSecours = true;
    await c.removeAllUserScripts();
    await c.addUserScript(userScript: _depart(kSecoursBase));
    await c.loadFile(assetFilePath: kSecoursAsset + kDepart);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool fait, Object? r) async {
        if (fait) return;
        final c = _controleur;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0720),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(kSite + kDepart)),
            initialUserScripts: UnmodifiableListView<UserScript>([_depart(kSite)]),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              cacheMode: CacheMode.LOAD_DEFAULT,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              useHybridComposition: true,
              geolocationEnabled: true,
              supportZoom: false,
              transparentBackground: true, // pas d'écran blanc au chargement : le fond nuit de l'application se voit
            ),
            onWebViewCreated: (c) {
              _controleur = c;
              c.addJavaScriptHandler(handlerName: 'nvEvent', callback: (args) => null);
            },
            // la caméra et le micro (La Forge, Le Direct, Palabre…) : on demande au téléphone, puis on répond à la page
            onPermissionRequest: (c, demande) async {
              final besoins = <Permission>[];
              for (final r in demande.resources) {
                if (r == PermissionResourceType.CAMERA || r == PermissionResourceType.CAMERA_AND_MICROPHONE) besoins.add(Permission.camera);
                if (r == PermissionResourceType.MICROPHONE || r == PermissionResourceType.CAMERA_AND_MICROPHONE) besoins.add(Permission.microphone);
              }
              if (besoins.isNotEmpty) {
                final etats = await besoins.request();
                if (etats.values.any((e) => !e.isGranted)) {
                  return PermissionResponse(resources: demande.resources, action: PermissionResponseAction.DENY);
                }
              }
              return PermissionResponse(resources: demande.resources, action: PermissionResponseAction.GRANT);
            },
            onGeolocationPermissionsShowPrompt: (c, origine) async {
              final e = await Permission.locationWhenInUse.request();
              return GeolocationPermissionShowPromptResponse(origin: origine, allow: e.isGranted, retain: false);
            },
            onReceivedError: (c, requete, erreur) async {
              if (requete.isForMainFrame ?? false) await _passerEnSecours(c);
            },
          ),
        ),
      ),
    );
  }
}
