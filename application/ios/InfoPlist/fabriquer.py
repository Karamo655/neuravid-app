# NEURAVID — textes des autorisations de l'iPhone dans les 11 langues (InfoPlist.strings).
# Lancé par la construction de l'application : python3 fabriquer.py <dossier Runner>
import os, sys
K = ['NSCameraUsageDescription', 'NSMicrophoneUsageDescription', 'NSLocationWhenInUseUsageDescription',
     'NSPhotoLibraryUsageDescription', 'NSPhotoLibraryAddUsageDescription']
T = {
 'en': ["NEURAVID uses the camera to film your videos, challenges and live streams.",
        "NEURAVID uses the microphone for the sound of your videos, live streams and calls.",
        "NEURAVID uses your location only if you choose to share it (your country, nearby live streams).",
        "NEURAVID opens your photos and videos only when you choose one to publish.",
        "NEURAVID saves to your photos the videos you choose to keep."],
 'fr': ["NEURAVID utilise la caméra pour filmer vos vidéos, vos défis et vos directs.",
        "NEURAVID utilise le micro pour le son de vos vidéos, de vos directs et de vos appels.",
        "NEURAVID utilise votre position seulement si vous choisissez de la partager (votre pays, les directs proches).",
        "NEURAVID ouvre vos photos et vidéos seulement quand vous choisissez d'en publier une.",
        "NEURAVID enregistre dans vos photos les vidéos que vous choisissez de garder."],
 'es': ["NEURAVID usa la cámara para grabar tus vídeos, retos y directos.",
        "NEURAVID usa el micrófono para el sonido de tus vídeos, directos y llamadas.",
        "NEURAVID usa tu ubicación solo si decides compartirla (tu país, directos cercanos).",
        "NEURAVID abre tus fotos y vídeos solo cuando eliges uno para publicar.",
        "NEURAVID guarda en tus fotos los vídeos que decides conservar."],
 'pt': ["O NEURAVID usa a câmera para gravar seus vídeos, desafios e transmissões ao vivo.",
        "O NEURAVID usa o microfone para o som dos seus vídeos, transmissões ao vivo e chamadas.",
        "O NEURAVID usa sua localização apenas se você decidir compartilhá-la (seu país, transmissões próximas).",
        "O NEURAVID abre suas fotos e vídeos apenas quando você escolhe um para publicar.",
        "O NEURAVID salva nas suas fotos os vídeos que você escolhe guardar."],
 'ar': ["يستخدم NEURAVID الكاميرا لتصوير مقاطعك وتحدياتك وبثوثك المباشرة.",
        "يستخدم NEURAVID الميكروفون لصوت مقاطعك وبثوثك المباشرة ومكالماتك.",
        "يستخدم NEURAVID موقعك فقط إذا اخترت مشاركته (بلدك، البثوث القريبة).",
        "يفتح NEURAVID صورك ومقاطعك فقط عندما تختار واحدًا لنشره.",
        "يحفظ NEURAVID في صورك المقاطع التي تختار الاحتفاظ بها."],
 'sw': ["NEURAVID hutumia kamera kurekodi video zako, changamoto na matangazo yako ya moja kwa moja.",
        "NEURAVID hutumia maikrofoni kwa sauti ya video zako, matangazo ya moja kwa moja na simu zako.",
        "NEURAVID hutumia mahali ulipo tu ukichagua kushiriki (nchi yako, matangazo ya karibu).",
        "NEURAVID hufungua picha na video zako tu unapochagua moja ya kuchapisha.",
        "NEURAVID huhifadhi kwenye picha zako video unazochagua kuweka."],
 'ha': ["NEURAVID tana amfani da kyamara don ɗaukar bidiyonka, ƙalubale da kai tsaye.",
        "NEURAVID tana amfani da makirufo don sautin bidiyonka, kai tsaye da kiran waya.",
        "NEURAVID tana amfani da wurinka ne kawai idan ka zaɓi raba shi (ƙasarka, kai tsaye na kusa).",
        "NEURAVID tana buɗe hotuna da bidiyonka ne kawai idan ka zaɓi ɗaya don wallafawa.",
        "NEURAVID tana ajiye a cikin hotunanka bidiyon da ka zaɓi ka adana."],
 'yo': ["NEURAVID ń lo kámẹ́rà láti ya àwọn fídíò rẹ, ìpèníjà àti ìgbóhùnsáfẹ́fẹ́ tààrà.",
        "NEURAVID ń lo makirofóònù fún ohùn fídíò rẹ, ìgbóhùnsáfẹ́fẹ́ tààrà àti ìpè.",
        "NEURAVID ń lo ibi tí o wà nìkan bí o bá yàn láti pín in (orílẹ̀-èdè rẹ, ìgbóhùnsáfẹ́fẹ́ tó súnmọ́).",
        "NEURAVID ń ṣí àwọn fọ́tò àti fídíò rẹ nìkan nígbà tí o bá yan ọ̀kan láti tẹ̀ jáde.",
        "NEURAVID ń fi àwọn fídíò tí o yàn láti tọ́jú pamọ́ sínú fọ́tò rẹ."],
 'wo': ["NEURAVID dafay jëfandikoo kamera ngir filme sa yi widewo, sa yi kàtte ak sa yi live.",
        "NEURAVID dafay jëfandikoo mikoro ngir baatu sa yi widewo, sa yi live ak sa yi woote.",
        "NEURAVID du jëfandikoo fi nga nekk su fekkee tànnoo koo séddoo (sa réew, live yi jege).",
        "NEURAVID du ubbi sa yi nataal ak widewo su fekkee tànnoo benn ngir siiwal ko.",
        "NEURAVID dafay denc ci sa yi nataal widewo yi nga tànn ngir denc."],
 'bm': ["NEURAVID bɛ kamera kɛ ka i ka widewo, kafiya ani i ka live ja ta.",
        "NEURAVID bɛ mikoro kɛ i ka widewo, i ka live ani i ka wele kan kama.",
        "NEURAVID bɛ i sigiyɔrɔ kɛ ni i y'a sugandi k'a tila dɔrɔn (i ka jamana, live surunw).",
        "NEURAVID bɛ i ka jaw ni widewo da wuli ni i ye kelen sugandi k'a jira dɔrɔn.",
        "NEURAVID bɛ i ye widewo minnu sugandi ka mara, olu bila i ka jaw la."],
 'ln': ["NEURAVID esalelaka kamera mpo na kozwa bavideo na yo, mitako mpe ba live na yo.",
        "NEURAVID esalelaka mikro mpo na lolaka ya bavideo na yo, ba live mpe mabengi na yo.",
        "NEURAVID esalelaka esika ozali kaka soki oponi kokabola yango (mboka na yo, ba live ya pene).",
        "NEURAVID efungolaka bafoto mpe bavideo na yo kaka soki oponi moko mpo na kotya yango.",
        "NEURAVID ebombaka na bafoto na yo bavideo oponi kobomba."],
}
def esc(s): return s.replace('\\', '\\\\').replace('"', '\\"')
dossier = sys.argv[1]
for l, v in T.items():
    assert len(v) == len(K), l
    d = os.path.join(dossier, l + '.lproj'); os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, 'InfoPlist.strings'), 'w', encoding='utf-8') as f:
        f.write('"CFBundleDisplayName" = "NEURAVID";\n')
        for k, s in zip(K, v): f.write('"%s" = "%s";\n' % (k, esc(s)))
print(len(T), 'langues')
