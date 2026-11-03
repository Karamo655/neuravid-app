// NEURAVID — l'application officielle (Android et iPhone), construite par GitHub
// (.github/workflows/application-officielle.yml). Propriétaire : Karamo Fanta Sacko.
//
// Principe : l'application ouvre le site de NEURAVID. Tout ce qui est publié sur le site (écrans, modules, corrections,
// traductions, adresse des serveurs dans nv-config.js) arrive donc dans l'application sans nouvelle version sur les magasins.
// Sans réseau, la copie du site embarquée dans l'application prend le relais.
//
// Différences avec l'APK « NEURAVID Aperçu » (apk/lib/main.dart) :
//  - JAMAIS de drapeau NV_APERCU : les modules savent qu'ils sont dans l'application officielle, ils n'affichent
//    jamais d'exemples, seulement les vraies données des serveurs (« — » quand une valeur est inconnue) ;
//  - la page de départ est l'accueil (index.html), pas demo.html ;
//  - les liens extérieurs (courriel contact@neuravid.com, autres sites) s'ouvrent hors de l'application.
//
// L'adresse du site et la page de départ viennent de application/config.env (passées par --dart-define).
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

const String kSite = String.fromEnvironment('NV_SITE', defaultValue: 'https://karamo655.github.io/neuravid-app/');
const String kDepart = String.fromEnvironment('NV_DEPART', defaultValue: 'index.html');
const String kSecoursAsset = 'assets/web/';

/// Hors connexion : la copie embarquée. Android et iPhone ne la rangent pas au même endroit ; loadFile s'en charge,
/// et les modules s'ouvrent entre eux à côté de la page (NV_MODULES_BASE = './').
const String kSecoursBase = './';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0B0720),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0B0720),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const Neuravid());
}

class Neuravid extends StatelessWidget {
  const Neuravid({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEURAVID',
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

  /// Posé avant tout script de chaque page : où sont les autres modules, la langue du téléphone.
  /// Ne pose jamais NV_API_BASE ici : nv-config.js, sur le site, est le seul endroit qui donne l'adresse des serveurs.
  /// Ne pose JAMAIS NV_APERCU (c'est le signal de l'application de démonstration).
  UserScript _depart(String base) {
    final langue = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return UserScript(
      source: '''
window.NV_MODULES_BASE = ${jsonEncode(base)};
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

  /// Une adresse du site (ou de la copie embarquée) reste dans l'application ; le reste s'ouvre à l'extérieur.
  bool _chezNous(Uri u) {
    if (u.scheme == 'file' || u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob') return true;
    final site = Uri.parse(kSite);
    return (u.scheme == 'https' || u.scheme == 'http') && u.host == site.host;
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
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
              allowsBackForwardNavigationGestures: true,
            ),
            onWebViewCreated: (c) {
              _controleur = c;
              // Les événements des modules (ouvrir un module, signalement, achat…) : à brancher sur les serveurs.
              c.addJavaScriptHandler(handlerName: 'nvEvent', callback: (args) => null);
            },
            shouldOverrideUrlLoading: (c, action) async {
              final u = action.request.url;
              if (u == null || _chezNous(u)) return NavigationActionPolicy.ALLOW;
              try {
                await launchUrl(u, mode: LaunchMode.externalApplication);
              } catch (_) {/* rien : le lien ne s'ouvre pas, l'application reste où elle est */}
              return NavigationActionPolicy.CANCEL;
            },
            // la caméra et le micro (La Forge, Le Direct, Palabre…). Android : on demande au téléphone, puis on répond
            // à la page. iPhone : le système pose lui-même la question (textes dans Info.plist).
            onPermissionRequest: (c, demande) async {
              if (Platform.isAndroid) {
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
