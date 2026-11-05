// Essais du pont (lancés par GitHub avant chaque construction : flutter test).
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/pont.dart';

void main() {
  const page = 'https://karamo655.github.io/neuravid-app/NV_MODULE_Arena.html';
  test('ouvrir un module : les trois formes de message', () {
    expect(adresseModule({'target': 'NVCinemaWorld'}, page), 'https://karamo655.github.io/neuravid-app/NV_MODULE_CinemaWorld.html');
    expect(adresseModule({'module': 'Live', 'live': 'x'}, page), 'https://karamo655.github.io/neuravid-app/NV_MODULE_Live.html');
    expect(adresseModule({'target': 'Player'}, page), 'https://karamo655.github.io/neuravid-app/NV_MODULE_Iris.html');
    expect(adresseModule({'url': 'NV_MODULE_Report.html'}, page), 'https://karamo655.github.io/neuravid-app/NV_MODULE_Report.html');
    expect(adresseModule({'target': 'Notifications'}, page), 'https://karamo655.github.io/neuravid-app/NV_MODULE_Notifications.html');
    expect(adresseModule({'url': 'javascript:alert(1)'}, page), isNull);
    expect(adresseModule({'target': '../../x'}, page), isNull);
    expect(adresseModule({}, page), isNull);
  });
  test('hors connexion : à côté de la page', () {
    expect(adresseModule({'module': 'Baobab'}, 'file:///android_asset/flutter_assets/assets/web/NV_MODULE_Orbite.html'),
        'file:///android_asset/flutter_assets/assets/web/NV_MODULE_Baobab.html');
  });
  test('vibration : légère par défaut, moyenne sur demande, rien d\'autre', () {
    expect(forceHaptique({}), 'leger');
    expect(forceHaptique({'force': 'moyen'}), 'moyen');
    expect(forceHaptique({'force': 'fort'}), isNull);
  });
  test('identifiant du module', () {
    expect(idModule({'target': 'NVEtendard'}), 'Etendard');
    expect(idModule({'module': 'Live'}), 'Live');
    expect(idModule({'url': 'x'}), isNull);
  });
  test('texte à partager', () {
    expect(texteAPartager({'texte': 'Regardez', 'lien': 'https://x.y/1'}), 'Regardez\nhttps://x.y/1');
    expect(texteAPartager({'texte': 'https://x.y/1', 'lien': 'https://x.y/1'}), 'https://x.y/1');
    expect(texteAPartager({}), '');
  });
  test('octets : base64, data: et texte', () {
    expect(octets({'base64': base64Encode([1, 2, 3])}), [1, 2, 3]);
    expect(utf8.decode(octets({'donnees': 'data:text/calendar;base64,${base64Encode(utf8.encode('BEGIN'))}'})!), 'BEGIN');
    expect(utf8.decode(octets({'contenu': '{"a":1}'})!), '{"a":1}');
    expect(octets({}), isNull);
  });
  test('noms de fichiers sûrs', () {
    expect(nomSur('ma vidéo', 'video/mp4'), 'ma_vid_o.mp4');
    expect(nomSur('../../etc/passwd', ''), 'etc_passwd');
    expect(nomSur(null, 'image/png'), 'NEURAVID.png');
    expect(nomSur('agenda.ics', 'text/calendar'), 'agenda.ics');
  });
  test('galerie ou partage', () {
    expect(versGalerie('video/webm', 'x.webm'), isTrue);
    expect(versGalerie('', 'certificat.png'), isTrue);
    expect(versGalerie('application/json', 'gout.json'), isFalse);
  });
  test('assembler les morceaux dans l\'ordre, même reçus dans le désordre', () {
    final a = Assembleur();
    expect(a.ajouter({'id': 'f1', 'partie': 1, 'total': 2, 'base64': base64Encode([4, 5])}), isNull);
    expect(a.ajouter({'id': 'f1', 'partie': 0, 'total': 2, 'base64': base64Encode([1, 2, 3])}), [1, 2, 3, 4, 5]);
    expect(a.ajouter({'id': 'f2', 'partie': 3, 'total': 2, 'base64': ''}), isNull);
  });
  test('les 11 langues ont les 3 phrases', () {
    for (final l in ['fr', 'en', 'es', 'pt', 'ar', 'sw', 'ha', 'yo', 'wo', 'bm', 'ln']) {
      expect(kPhrases[l]!.length, 3, reason: l);
      for (final p in kPhrases[l]!) {
        expect(p.trim().isNotEmpty, isTrue, reason: l);
      }
    }
    expect(phrase('xx', 0), kPhrases['fr']![0]);
  });
}
