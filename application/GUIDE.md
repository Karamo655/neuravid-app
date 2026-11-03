# L'application officielle NEURAVID — le guide de Karamo

Ce dossier contient **l'application officielle de NEURAVID** pour Android (Google Play) et iPhone (App Store).
GitHub la construit, la signe avec **vos** clés et l'envoie aux magasins. Vous ne dépendez de personne pour la reconstruire.

## Comment elle fonctionne

- L'application **ouvre le site de NEURAVID**. Tout ce qui est publié sur le site arrive dans l'application **sans nouvelle version sur les magasins** :
  - les écrans, les modules, les corrections, les traductions ;
  - l'adresse des serveurs (fichier `web/nv-config.js`).
- **Sans Internet**, une copie du site embarquée dans l'application prend le relais. C'est la copie du jour de la construction.
- **Elle n'affiche jamais d'exemples** : seulement les vraies données des serveurs, et « — » quand une valeur est inconnue. Les exemples « Aperçu » restent dans l'application de démonstration « NEURAVID Aperçu ».
- **Ses réglages** sont dans `application/config.env` :
  - le nom ;
  - l'identifiant `com.neuravid.app` (il ne pourra **plus jamais** changer après la première publication) ;
  - la version ;
  - l'adresse du site.

## Ce qui demande une nouvelle version sur les magasins

Il faut une nouvelle version seulement si l'on change l'application elle-même :
- son nom, son icône ou son identifiant ;
- ses autorisations (caméra, micro, position) ;
- l'adresse du site qu'elle ouvre ;
- son code Flutter.

Dans ce cas : **Actions → Application officielle → Run workflow**, avec « Envoyer aux magasins » coché.

## Une seule fois : préparer Google Play (Android)

1. **Ajouter votre clé de signature dans GitHub.**
   - Dépôt `neuravid-app` → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
   - Créez les quatre secrets du fichier `SECRETS_A_COPIER.txt` (dans le dossier `cle_neuravid` que je vous ai remis) :
     - `ANDROID_KEYSTORE_BASE64` ;
     - `ANDROID_KEYSTORE_PASSWORD` ;
     - `ANDROID_KEY_ALIAS` ;
     - `ANDROID_KEY_PASSWORD`.
   - Gardez ce dossier en lieu sûr (clé USB, coffre en ligne) et ne le donnez à personne.
2. **Créer l'application dans la Play Console.**
   - **Créer une application** ;
   - nom : NEURAVID ; langue par défaut : français ; type : application ; gratuite.
3. **Construire.**
   - **Actions → Application officielle → Run workflow** ;
   - plateformes : android ; envoi aux magasins : non coché.
   - Après environ 15 minutes, la version apparaît dans **Releases** (`application-N`), avec deux fichiers :
     - `NEURAVID.aab`, pour Google Play ;
     - `NEURAVID.apk`, pour installer directement sur un téléphone.
4. **Faire le premier envoi à la main** (Google l'exige pour une nouvelle application).
   - Play Console → **Tests → Test interne → Créer une version** ;
   - importez `NEURAVID.aab` ;
   - acceptez la **signature d'application par Google Play**.
5. **Facultatif : l'envoi automatique pour les fois suivantes.**
   - Créez un **compte de service** Google Cloud avec sa clé JSON.
   - Invitez-le dans la Play Console (**Utilisateurs et autorisations**) avec le droit de publier des versions.
   - Collez le JSON dans un secret `PLAY_SERVICE_ACCOUNT_JSON`.
   - Ensuite, « Run workflow » avec envoi coché dépose chaque nouvelle version **en brouillon** sur la piste choisie. Vous la déployez d'un clic dans la Play Console.

## Une seule fois : préparer l'App Store (iPhone)

1. **Votre identifiant d'équipe.** developer.apple.com → **Account → Membership** → « Team ID », 10 caractères.
2. **Réserver l'identifiant.** developer.apple.com → **Certificates, Identifiers & Profiles → Identifiers → +** → App IDs → App :
   - Bundle ID (explicite) : `com.neuravid.app` ;
   - description : NEURAVID.
3. **Créer l'application.** App Store Connect → **Apps → + → Nouvelle app** :
   - iOS ; nom : NEURAVID ; langue principale : français ;
   - identifiant de lot : `com.neuravid.app` ; SKU : `neuravid`.
4. **Créer une clé d'accès pour GitHub.** App Store Connect → **Utilisateurs et accès → Intégrations → App Store Connect API → +** :
   - rôle **Admin** (nécessaire pour que GitHub signe l'application) ;
   - téléchargez le fichier `.p8` : il ne se télécharge **qu'une fois** ;
   - notez l'**ID de la clé** et l'**ID de l'émetteur** (« Issuer ID »).
5. **Ajouter quatre secrets dans GitHub** (même endroit que pour Android) :
   - `APPLE_TEAM_ID` : le Team ID ;
   - `APP_STORE_CONNECT_KEY_ID` : l'ID de la clé ;
   - `APP_STORE_CONNECT_ISSUER_ID` : l'Issuer ID ;
   - `APP_STORE_CONNECT_KEY_P8` : tout le texte du fichier `.p8`, y compris les lignes `-----BEGIN PRIVATE KEY-----` et `-----END PRIVATE KEY-----`.
6. **Construire et envoyer.**
   - **Run workflow** ; plateformes : ios ; « Envoyer aux magasins » coché.
   - L'application arrive dans **TestFlight** après le traitement d'Apple, 10 à 30 minutes.

## Avant de soumettre au public : ce que les magasins vérifieront

L'application elle-même est prête. Mais Apple et Google examinent ce qu'elle **fait** :

- **Des serveurs branchés et une connexion qui fonctionne.**
  - Aujourd'hui, sans serveurs, l'application montre des écrans vides avec « — ». C'est honnête, mais les deux magasins refusent une application vide. Apple applique pour cela ses règles 2.1 et 4.2 sur les applications incomplètes.
  - Il faut d'abord les vrais serveurs et l'écran de connexion et d'inscription, qui se termine par « Nos conditions ».
  - Donnez aux examinateurs un **compte de test**.
- **L'argent.**
  - Les pièces et les cadeaux achetés dans l'application doivent passer par les achats intégrés d'Apple et de Google.
  - Le retrait des gains des créateurs, lui, peut passer par vos moyens de paiement.
- **Les fiches des magasins.**
  - Icône 512 × 512 : `web/icones/nv-512.png` ; captures d'écran.
  - Politique de confidentialité : `https://karamo655.github.io/neuravid-app/NV_MODULE_Conditions.html?doc=confidentialite`.
  - Questionnaires « Sécurité des données » (Google) et « Confidentialité de l'app » (Apple).
  - Classification du contenu.
  - Public : à partir de 13 ans, pas destinée aux enfants.
- **Le domaine.**
  - Quand `app.neuravid.com` sera relié au site, mettez `SITE=https://app.neuravid.com/` dans `config.env` et publiez une nouvelle version.
  - L'ancienne adresse GitHub redirige alors vers le nouveau domaine : les téléphones qui ont encore l'ancienne version continuent de fonctionner.

## Les deux applications

| | NEURAVID Aperçu | NEURAVID (officielle) |
|---|---|---|
| Identifiant | `com.neuravid.apercu` | `com.neuravid.app` |
| Construction | `apk-demo.yml` (à chaque changement de `apk/`) | `application-officielle.yml` (à la demande) |
| Contenu | exemples « Aperçu » | vraies données seulement |
| Page de départ | `demo.html` | `index.html` (l'accueil) |
| Signature | démonstration | **vos** clés (Google Play, App Store) |
