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
//  - le pont (pont.js côté page, lib/pont.dart côté téléphone) fait ce que les modules confient à l'application :
//    ouvrir un module, partager, enregistrer une vidéo ou un fichier, ouvrir un lien ;
//  - les liens extérieurs (courriel contact@neuravid.com, autres sites) s'ouvrent hors de l'application.
//
// L'adresse du site et la page de départ viennent de application/config.env (passées par --dart-define).
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pont.dart';

const String kSite = String.fromEnvironment('NV_SITE', defaultValue: 'https://www.neuravid.com/');
const String kDepart = String.fromEnvironment('NV_DEPART', defaultValue: 'index.html');
const String kSecoursAsset = 'assets/web/';

/// Hors connexion : la copie embarquée. Les modules s'ouvrent entre eux à côté de la page (NV_MODULES_BASE = './').
const String kSecoursBase = './';

final GlobalKey<ScaffoldMessengerState> kMessages = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0B0720),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0B0720),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  String pont = '';
  try {
    pont = await rootBundle.loadString('assets/pont.js');
  } catch (_) {/* sans pont, les pages marchent quand même ; seules les actions confiées à l'application manquent */}
  runApp(Neuravid(pont: pont));
}

class Neuravid extends StatelessWidget {
  const Neuravid({super.key, required this.pont});
  final String pont;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEURAVID',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: kMessages,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF0B0720)),
      home: EcranNeuravid(pont: pont),
    );
  }
}

class EcranNeuravid extends StatefulWidget {
  const EcranNeuravid({super.key, required this.pont});
  final String pont;

  @override
  State<EcranNeuravid> createState() => _EcranNeuravidState();
}

class _EcranNeuravidState extends State<EcranNeuravid> {
  InAppWebViewController? _controleur;
  bool _enSecours = false;
  final Assembleur _assembleur = Assembleur();
  final Map<String, DateTime> _recents = {};

  /// Posé avant tout script de chaque page : où sont les autres modules, la langue du téléphone.
  /// Ne pose jamais NV_API_BASE ici : nv-config.js, sur le site, est le seul endroit qui donne l'adresse des serveurs.
  /// Ne pose JAMAIS NV_APERCU (c'est le signal de l'application de démonstration).
  List<UserScript> _scripts(String base) {
    final langue = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return [
      UserScript(
        source: '''
window.NV_MODULES_BASE = ${jsonEncode(base)};
if(!window.NV_LANG) window.NV_LANG = ${jsonEncode(langue)};
''',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      if (widget.pont.isNotEmpty) UserScript(source: widget.pont, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
    ];
  }

  Future<void> _passerEnSecours(InAppWebViewController c) async {
    if (_enSecours) return;
    _enSecours = true;
    await c.removeAllUserScripts();
    await c.addUserScripts(userScripts: _scripts(kSecoursBase));
    await c.loadFile(assetFilePath: kSecoursAsset + kDepart);
  }

  /// Une adresse du site (ou de la copie embarquée) reste dans l'application ; le reste s'ouvre à l'extérieur.
  bool _chezNous(Uri u) {
    if (u.scheme == 'file' || u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob') return true;
    final site = Uri.parse(kSite);
    // Le site NEURAVID a plusieurs adresses (www.neuravid.com, neuravid.com, et l'ancienne adresse de GitHub qui y
    // redirige) : toutes restent dans l'application. Sinon une redirection ouvrirait le navigateur du téléphone.
    const nos = {'www.neuravid.com', 'neuravid.com', 'karamo655.github.io'};
    return (u.scheme == 'https' || u.scheme == 'http') && (u.host == site.host || nos.contains(u.host));
  }

  Future<void> _ouvrirLien(String? url) async {
    final c = _controleur;
    if (url == null || url.isEmpty || c == null) return;
    final u = Uri.tryParse(url);
    if (u == null) return;
    if (_chezNous(u) && u.scheme != 'data' && u.scheme != 'blob') {
      await c.loadUrl(urlRequest: URLRequest(url: WebUri(u.toString())));
    } else if (const ['https', 'http', 'mailto', 'tel', 'sms', 'whatsapp'].contains(u.scheme)) {
      try {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      } catch (_) {/* aucune application pour ce lien */}
    }
  }

  Future<String> _langue() async {
    try {
      final l = await _controleur?.evaluateJavascript(source: "String(window.NV_LANG||document.documentElement.lang||'')");
      final s = (l ?? '').toString().toLowerCase();
      if (s.length >= 2 && kPhrases.containsKey(s.substring(0, 2))) return s.substring(0, 2);
    } catch (_) {/* la page ne répond pas */}
    final t = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return kPhrases.containsKey(t) ? t : 'fr';
  }

  Future<void> _dire(int i) async {
    final l = await _langue();
    kMessages.currentState?.showSnackBar(SnackBar(content: Text(phrase(l, i)), behavior: SnackBarBehavior.floating));
  }

  /// Le même fichier envoyé deux fois en quelques secondes (lien + message, comme l'agenda des événements) : une seule fois.
  bool _doublon(String nom, int taille) {
    final k = '$nom/$taille';
    final now = DateTime.now();
    _recents.removeWhere((_, t) => now.difference(t).inSeconds > 10);
    if (_recents.containsKey(k)) return true;
    _recents[k] = now;
    return false;
  }

  /// Enregistre et dit où c'est allé. Renvoie true si c'est fait.
  Future<bool> _garder(Uint8List donnees, String? nom, String type, {bool annoncer = true}) async {
    final n = nomSur(nom, type);
    if (_doublon(n, donnees.length)) return true;
    final ou = await enregistrer(donnees, n, type);
    if (annoncer) {
      if (ou == 'galerie') await _dire(0);
      if (ou == null) await _dire(1);
    }
    return ou != null;
  }

  Future<dynamic> _morceau(List<dynamic> args) async {
    if (args.isEmpty || args[0] is! Map) return {'ok': false};
    final p = Map<String, dynamic>.from(args[0] as Map);
    final tout = _assembleur.ajouter(p);
    if (tout == null) return {'ok': true};
    final fait = await _garder(tout, p['nom']?.toString(), (p['type'] ?? '').toString());
    return {'ok': fait};
  }

  int _dernierHaptique = 0;
  Future<dynamic> _evenement(List<dynamic> args) async {
    final c = _controleur;
    if (c == null || args.isEmpty || args[0] is! Map) return null;
    final msg = Map<String, dynamic>.from(args[0] as Map);
    final type = (msg['type'] ?? '').toString();
    // forme habituelle {source, module, type, payload} ; forme brute d'Orbite {type, module, live}
    final p = msg['payload'] is Map ? Map<String, dynamic>.from(msg['payload'] as Map) : msg;
    switch (type) {
      case 'open_module':
      case 'open': {
        final avant = (await c.getUrl())?.toString() ?? '';
        final cible = adresseModule(p, avant.isEmpty ? kSite + kDepart : avant);
        if (cible == null) return null;
        final id = idModule(p);
        final ctx = p['contexte'] is Map ? p['contexte'] : (p['live'] != null ? {'live': p['live'], 'depuis': msg['module']} : null);
        // la plupart des modules partent seuls (par NVLien ou après 450 ms) ; on n'ouvre que si la page n'a pas bougé
        Future.delayed(const Duration(milliseconds: 700), () async {
          final apres = (await c.getUrl())?.toString() ?? '';
          if (apres != avant) return;
          if (id != null && ctx != null) {
            await c.evaluateJavascript(
                source: "try{ if(!sessionStorage.getItem('nv_ctx_$id')) sessionStorage.setItem('nv_ctx_$id', ${jsonEncode(jsonEncode(ctx))}); }catch(e){}");
          }
          await c.loadUrl(urlRequest: URLRequest(url: WebUri(cible)));
        });
        return null;
      }
      case 'module_close': {
        if (await c.canGoBack()) {
          await c.goBack();
        } else {
          await c.loadUrl(urlRequest: URLRequest(url: WebUri(kSite + kDepart)));
        }
        return null;
      }
      case 'share_request':
      case 'share': {
        final t = texteAPartager(p);
        if (t.isNotEmpty) await Share.share(t);
        return null;
      }
      case 'share_video_file': {
        final b = octets(p);
        if (b == null) return {'ok': false, 'message': phrase(await _langue(), 1)};
        final fait = await _garder(b, p['nom']?.toString(), (p['type'] ?? 'video/mp4').toString(), annoncer: false);
        return fait ? {'ok': true} : {'ok': false, 'message': phrase(await _langue(), 1)};
      }
      case 'save_file':
      case 'download_request': {
        final b = octets(p);
        final fait = b != null && await _garder(b, p['nom']?.toString(), (p['type'] ?? '').toString());
        if (b == null) await _dire(1);
        await c.evaluateJavascript(
            source: "try{ window.dispatchEvent(new CustomEvent('nv:file_saved', {detail:${jsonEncode({'nom': p['nom'], 'ok': fait})}})); }catch(e){}");
        return {'ok': fait};
      }
      case 'download': {
        // Iris : une vidéo publiée (adresse https) est téléchargée ici ; une vidéo du téléphone passe par NVTelecharger
        final src = p['src'];
        if (src is String && src.startsWith('http')) {
          try {
            final req = await HttpClient().getUrl(Uri.parse(src));
            final rep = await req.close();
            final bb = BytesBuilder(copy: false);
            await for (final x in rep) {
              bb.add(x);
            }
            await _garder(bb.takeBytes(), p['nom']?.toString(), rep.headers.contentType?.mimeType ?? 'video/mp4');
          } catch (_) {
            await _dire(1);
          }
        }
        return null;
      }
      case 'haptic': {
        // 5 nov. 2026 : la petite vibration quand on touche une tuile hexagonale de l'accueil (jamais plus d'une par 80 ms)
        final f = forceHaptique(p);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (f != null && now - _dernierHaptique >= 80) {
          _dernierHaptique = now;
          if (f == 'moyen') { await HapticFeedback.mediumImpact(); } else { await HapticFeedback.selectionClick(); }
        }
        return null;
      }
      case 'open_url': {
        final u = p['url']?.toString();
        if (u != null && (u.startsWith('https://') || u.startsWith('http://'))) {
          try {
            await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
          } catch (_) {/* aucun navigateur */}
        }
        return null;
      }
      case 'login_required': {
        // 4 nov. 2026 : la connexion se fait dans L'Entrée (NV_MODULE_Entree.html) ; on revient ensuite au module
        final avant = (await c.getUrl())?.toString() ?? (kSite + kDepart);
        final cible = Uri.parse(avant).resolve('NV_MODULE_Entree.html').toString();
        final ctx = {'vue': 'connexion', 'retour': msg['module'], 'raison': 'login_required', 'pour': p['pour']};
        await c.evaluateJavascript(source: "try{ sessionStorage.setItem('nv_ctx_Entree', ${jsonEncode(jsonEncode(ctx))}); }catch(e){}");
        await c.loadUrl(urlRequest: URLRequest(url: WebUri(cible)));
        return null;
      }
      case 'open_link': {
        await _ouvrirLien(p['url']?.toString());
        return null;
      }
    }
    final rappel = kAttentesServeur[type];
    if (rappel != null && p['idem'] != null) {
      final r = {'idem': p['idem'], 'success': false, 'reason': phrase(await _langue(), 2)};
      await c.evaluateJavascript(source: "try{ if(typeof window.$rappel==='function') window.$rappel(${jsonEncode(r)}); }catch(e){}");
    }
    return null;
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
            initialUserScripts: UnmodifiableListView<UserScript>(_scripts(kSite)),
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
              c.addJavaScriptHandler(handlerName: 'nvEvent', callback: _evenement);
              c.addJavaScriptHandler(handlerName: 'nvEnregistrer', callback: _morceau);
              c.addJavaScriptHandler(handlerName: 'nvTelecharger', callback: _morceau);
              c.addJavaScriptHandler(
                  handlerName: 'nvPartager',
                  callback: (args) async {
                    if (args.isEmpty || args[0] is! Map) return null;
                    final t = texteAPartager(Map<String, dynamic>.from(args[0] as Map));
                    if (t.isNotEmpty) await Share.share(t);
                    return null;
                  });
              c.addJavaScriptHandler(
                  handlerName: 'nvOuvrirLien',
                  callback: (args) async {
                    if (args.isNotEmpty && args[0] is Map) await _ouvrirLien((args[0] as Map)['url']?.toString());
                    return null;
                  });
            },
            shouldOverrideUrlLoading: (c, action) async {
              final u = action.request.url;
              if (u == null || _chezNous(u)) return NavigationActionPolicy.ALLOW;
              await _ouvrirLien(u.toString());
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
