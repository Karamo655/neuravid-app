// NEURAVID — le pont côté téléphone : ce que les modules confient à l'application officielle.
// Recensé le 3 novembre 2026 dans les 38 pages (voir application/README.md, « Native bridge »).
//
//  - ouvrir un module (open_module / open, trois formes de message) et fermer un module (module_close) ;
//  - partager (share_request / share, navigator.share) ;
//  - enregistrer un fichier (NVTelecharger, nvTelecharger, share_video_file, save_file, download_request, download) :
//    une vidéo ou une image va dans la galerie ; un autre fichier passe par la feuille de partage (Fichiers, Drive…) ;
//  - une petite vibration (haptic : force 'leger' ou 'moyen') quand on touche une tuile de l'accueil ;
//  - ouvrir un lien (open_url, open_link, window.open) : NEURAVID dans l'application, le reste dans le navigateur ;
//  - ce qui demande les serveurs (signalement, coffre de fidélité, votes de Battle) reçoit tout de suite une réponse
//    honnête « pas encore disponible » au lieu d'une attente de 15 à 20 secondes. Rien n'est jamais déclaré réussi.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// La force de la vibration demandée par un module (`haptic`) : 'leger' (par défaut) ou 'moyen' ; null si refusée.
String? forceHaptique(Map<String, dynamic> p) {
  final f = (p['force'] ?? 'leger').toString();
  return (f == 'leger' || f == 'moyen') ? f : null;
}

/// Les fichiers des modules dont le nom diffère de l'identifiant.
const Map<String, String> kFichiers = {'Player': 'Iris'};

/// L'adresse du module à ouvrir, à partir d'un message d'un module, ou null.
/// Trois formes : {url}, {target:'NVCinemaWorld' ou 'Live'}, {module:'Live'} (Orbite et Viral Storm).
String? adresseModule(Map<String, dynamic> p, String pageCourante) {
  final url = p['url'];
  if (url is String && url.isNotEmpty) {
    final u = Uri.tryParse(pageCourante)?.resolve(url);
    if (u == null || !(u.scheme == 'https' || u.scheme == 'http' || u.scheme == 'file')) return null;
    return u.toString();
  }
  var id = (p['target'] ?? p['module'])?.toString() ?? '';
  id = id.replaceFirst(RegExp(r'^NV(?=[A-Z])'), '');
  if (!RegExp(r'^[A-Za-z_]{2,40}$').hasMatch(id)) return null;
  final page = Uri.tryParse(pageCourante);
  if (page == null) return null;
  return page.resolve('NV_MODULE_${kFichiers[id] ?? id}.html').toString();
}

/// L'identifiant du module visé (pour son contexte nv_ctx_<id>), ou null.
String? idModule(Map<String, dynamic> p) {
  final id = (p['target'] ?? p['module'])?.toString().replaceFirst(RegExp(r'^NV(?=[A-Z])'), '');
  return id != null && RegExp(r'^[A-Za-z_]{2,40}$').hasMatch(id) ? id : null;
}

/// Le texte à partager : le texte puis le lien, sans doublon.
String texteAPartager(Map<String, dynamic> p) {
  final morceaux = <String>[];
  for (final k in ['titre', 'texte', 'text', 'lien', 'url', 'link']) {
    final v = p[k];
    if (v is String && v.trim().isNotEmpty && !morceaux.contains(v.trim())) morceaux.add(v.trim());
  }
  return morceaux.join('\n');
}

/// Les octets d'un fichier envoyé en base64 ou en adresse « data: ».
Uint8List? octets(Map<String, dynamic> p) {
  try {
    final b = p['base64'];
    if (b is String && b.isNotEmpty) return base64Decode(b);
    final d = p['donnees'] ?? p['data'];
    if (d is String && d.startsWith('data:')) return UriData.parse(d).contentAsBytes();
    final c = p['contenu'];
    if (c is String) return Uint8List.fromList(utf8.encode(c));
  } catch (_) {/* fichier illisible */}
  return null;
}

/// Un nom de fichier sûr.
String nomSur(String? nom, String type) {
  var n = (nom ?? '').replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'^[._]+'), '');
  if (n.isEmpty) n = 'NEURAVID';
  if (!n.contains('.')) {
    final ext = {'video/mp4': '.mp4', 'video/webm': '.webm', 'video/quicktime': '.mov', 'image/png': '.png', 'image/jpeg': '.jpg',
      'application/json': '.json', 'text/csv': '.csv', 'application/pdf': '.pdf', 'text/calendar': '.ics', 'audio/webm': '.webm',
      'audio/mpeg': '.mp3', 'audio/wav': '.wav', 'text/plain': '.txt'}[type.split(';').first.trim()];
    if (ext != null) n += ext;
  }
  return n.length > 80 ? n.substring(n.length - 80) : n;
}

bool versGalerie(String type, String nom) =>
    type.startsWith('video/') || type.startsWith('image/') || RegExp(r'\.(mp4|webm|mov|png|jpe?g|gif)$', caseSensitive: false).hasMatch(nom);

/// Où le fichier est allé : 'galerie', 'partage', ou null (échec).
Future<String?> enregistrer(Uint8List donnees, String nom, String type) async {
  try {
    final dossier = await getTemporaryDirectory();
    final f = File('${dossier.path}/${DateTime.now().millisecondsSinceEpoch}_$nom');
    await f.writeAsBytes(donnees, flush: true);
    if (versGalerie(type, nom)) {
      try {
        if (!await Gal.hasAccess()) await Gal.requestAccess();
        if (type.startsWith('image/') || RegExp(r'\.(png|jpe?g|gif)$', caseSensitive: false).hasMatch(nom)) {
          await Gal.putImage(f.path, album: 'NEURAVID');
        } else {
          await Gal.putVideo(f.path, album: 'NEURAVID');
        }
        return 'galerie';
      } catch (_) {/* la galerie refuse (format, autorisation) : la feuille de partage prend le relais */}
    }
    await Share.shareXFiles([XFile(f.path, mimeType: type.isEmpty ? null : type, name: nom)]);
    return 'partage';
  } catch (_) {
    return null;
  }
}

/// Assemble les morceaux de NVTelecharger / nvTelecharger : {id, nom, type, partie, total, base64}.
class Assembleur {
  final Map<String, List<Uint8List?>> _parts = {};
  /// Renvoie le fichier complet quand le dernier morceau arrive, sinon null.
  Uint8List? ajouter(Map<String, dynamic> p) {
    final id = (p['id'] ?? '').toString();
    final total = (p['total'] is num) ? (p['total'] as num).toInt() : 1;
    final partie = (p['partie'] is num) ? (p['partie'] as num).toInt() : 0;
    if (total < 1 || total > 4000 || partie < 0 || partie >= total) return null;
    final morceau = base64Decode((p['base64'] ?? '').toString());
    final l = _parts.putIfAbsent(id, () => List<Uint8List?>.filled(total, null));
    if (l.length != total) return null;
    l[partie] = morceau;
    if (l.any((x) => x == null)) return null;
    _parts.remove(id);
    final b = BytesBuilder(copy: false);
    for (final x in l) b.add(x!);
    return b.takeBytes();
  }
}

/// Les phrases de l'application (11 langues ; sw, ha, yo, wo, bm et ln à faire relire comme le reste).
const Map<String, List<String>> kPhrases = {
  //        enregistré dans la galerie            impossible d'enregistrer                 pas encore disponible (serveurs)
  'fr': ['Enregistré dans votre galerie.', 'Impossible d\'enregistrer ce fichier.', 'Pas encore disponible : NEURAVID n\'est pas encore relié à ses serveurs.'],
  'en': ['Saved to your gallery.', 'This file could not be saved.', 'Not available yet: NEURAVID is not yet connected to its servers.'],
  'es': ['Guardado en tu galería.', 'No se pudo guardar este archivo.', 'Aún no disponible: NEURAVID todavía no está conectado a sus servidores.'],
  'pt': ['Salvo na sua galeria.', 'Não foi possível salvar este arquivo.', 'Ainda não disponível: o NEURAVID ainda não está conectado aos seus servidores.'],
  'ar': ['تم الحفظ في معرض الصور.', 'تعذّر حفظ هذا الملف.', 'غير متاح بعد: NEURAVID غير متصل بخوادمه بعد.'],
  'sw': ['Imehifadhiwa kwenye matunzio yako.', 'Faili hii haikuweza kuhifadhiwa.', 'Bado haipatikani: NEURAVID bado haijaunganishwa na seva zake.'],
  'ha': ['An adana a cikin hotunanka.', 'Ba a iya adana wannan fayil ba.', 'Babu shi tukuna: NEURAVID bai haɗu da sabobinsa ba tukuna.'],
  'yo': ['A ti fi pamọ́ sínú àwọn àwòrán rẹ.', 'A kò lè fi fáìlì yìí pamọ́.', 'Kò tíì sí: NEURAVID kò tíì so pọ̀ mọ́ àwọn sáfà rẹ̀.'],
  'wo': ['Denc nañu ko ci sa galeri.', 'Mënunu denc fichier bii.', 'Amagul ba léegi: NEURAVID jokkoogul ak ay serweeram ba léegi.'],
  'bm': ['A marala i ka jaw la.', 'Nin dosiye tɛ se ka mara.', 'A tɛ sɔrɔ fɔlɔ: NEURAVID ma tugu a ka sɛriwɛriw la fɔlɔ.'],
  'ln': ['Ebombami na galeri na yo.', 'Tokokaki kobomba fisyé oyo te.', 'Ezali naino te: NEURAVID ekangami naino te na baserveur na yango.'],
};
String phrase(String langue, int i) => (kPhrases[langue] ?? kPhrases['fr']!)[i];

/// Les confirmations que les modules attendent et qui demandent les serveurs : la fonction à rappeler.
const Map<String, String> kAttentesServeur = {
  'report_submit': 'NVReportConfirm',
  'loyalty_chest_request': 'NVFideliteCoffre',
  'battle_vote_request': 'NVBattleConfirm',
  'battle_prediction_request': 'NVBattleConfirm',
  'battle_encore_request': 'NVBattleConfirm',
  'battle_rematch_request': 'NVBattleConfirm',
};
