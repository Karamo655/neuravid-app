// NEURAVID — les achats intégrés de l'App Store (28 nov. 2026).
//
// Sur iPhone, les NVCoins s'achètent SEULEMENT par les achats intégrés d'Apple (règle 3.1.1).
// La page parle au téléphone par un seul gestionnaire « nvMagasin » :
//   {action:'produits', ids:[…]}            → {ok, produits:[{id, prix, valeur, devise, titre}], absents}
//   {action:'acheter', id, compte}           → {ok, produit, transaction, recu}   (recu = transaction signée par Apple, JWS)
//                                            | {ok:false, raison:'annule'|'erreur'|'en_cours'|'produit_inconnu'|'indisponible'|'attente'}
//   {action:'terminer', transaction}         → {ok}   (appelé SEULEMENT après le crédit par le serveur de NEURAVID)
//   {action:'en_attente'}                    → {ok, recus:[…]}   (achats payés mais pas encore crédités : jamais perdus)
// Une transaction payée n'est « terminée » auprès d'Apple qu'une fois créditée : si l'application se ferme entre les deux,
// l'App Store la redonne au prochain lancement et la page la crédite (window.NVMagasinRecu).
// Sur Android, rien ne s'ouvre ici (le dépôt de NEURAVID reste celui du site).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

final RegExp _reId = RegExp(r'^[A-Za-z0-9._-]{3,100}$');
final RegExp _reUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

class Magasin {
  Magasin._();
  static final Magasin instance = Magasin._();

  bool get actif => Platform.isIOS;
  InAppWebViewController? controleur;
  StreamSubscription<List<PurchaseDetails>>? _abo;
  final Map<String, ProductDetails> _produits = {};
  final Map<String, PurchaseDetails> _aTerminer = {};
  Completer<Map<String, dynamic>>? _achat;
  String? _achatProduit;

  void demarrer() {
    if (!actif || _abo != null) return;
    _abo = InAppPurchase.instance.purchaseStream.listen(_recevoir, onError: (_) {});
  }

  Map<String, dynamic> _recu(PurchaseDetails d) => {
        'ok': true,
        'produit': d.productID,
        'transaction': d.purchaseID ?? '',
        'recu': d.verificationData.serverVerificationData,
      };

  void _recevoir(List<PurchaseDetails> liste) {
    for (final d in liste) {
      switch (d.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          if (d.pendingCompletePurchase) InAppPurchase.instance.completePurchase(d);
          if (_achat != null && d.productID == _achatProduit) {
            _achat!.complete({'ok': false, 'raison': d.status == PurchaseStatus.canceled ? 'annule' : 'erreur'});
            _achat = null;
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final t = d.purchaseID ?? '';
          if (t.isEmpty) break;
          _aTerminer[t] = d;
          final r = _recu(d);
          if (_achat != null && d.productID == _achatProduit) {
            _achat!.complete(r);
            _achat = null;
          } else {
            // payé plus tôt (application fermée, achat « Demander à acheter » validé plus tard…) : la page le crédite
            controleur?.evaluateJavascript(source: 'window.NVMagasinRecu && window.NVMagasinRecu(${jsonEncode(r)})');
          }
          break;
      }
    }
  }

  Future<dynamic> gerer(List<dynamic> args) async {
    if (!actif) return {'ok': false, 'raison': 'indisponible'};
    final o = args.isNotEmpty && args[0] is Map ? Map<String, dynamic>.from(args[0] as Map) : <String, dynamic>{};
    switch (o['action']) {
      case 'produits':
        return _lireProduits(o['ids']);
      case 'acheter':
        return _acheter(o['id'], o['compte']);
      case 'terminer':
        final t = o['transaction'];
        final d = t is String ? _aTerminer.remove(t) : null;
        if (d != null && d.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(d);
        return {'ok': d != null};
      case 'en_attente':
        return {'ok': true, 'recus': _aTerminer.values.map(_recu).toList()};
    }
    return {'ok': false, 'raison': 'action'};
  }

  Future<Map<String, dynamic>> _lireProduits(dynamic ids) async {
    final demande = <String>{};
    if (ids is List) {
      for (final x in ids) {
        if (x is String && _reId.hasMatch(x) && demande.length < 30) demande.add(x);
      }
    }
    if (demande.isEmpty) return {'ok': false, 'raison': 'produits'};
    if (!await InAppPurchase.instance.isAvailable()) return {'ok': false, 'raison': 'indisponible'};
    final r = await InAppPurchase.instance.queryProductDetails(demande);
    for (final p in r.productDetails) {
      _produits[p.id] = p;
    }
    return {
      'ok': true,
      'produits': r.productDetails
          .map((p) => {'id': p.id, 'prix': p.price, 'valeur': p.rawPrice, 'devise': p.currencyCode, 'titre': p.title})
          .toList(),
      'absents': r.notFoundIDs,
    };
  }

  Future<Map<String, dynamic>> _acheter(dynamic id, dynamic compte) async {
    final p = id is String ? _produits[id] : null;
    if (p == null) return {'ok': false, 'raison': 'produit_inconnu'};
    if (_achat != null) return {'ok': false, 'raison': 'en_cours'};
    _achat = Completer<Map<String, dynamic>>();
    _achatProduit = p.id;
    final param = PurchaseParam(
        productDetails: p, applicationUserName: compte is String && _reUuid.hasMatch(compte) ? compte : null);
    bool lance;
    try {
      lance = await InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: true);
    } catch (_) {
      lance = false;
    }
    if (!lance) {
      _achat = null;
      return {'ok': false, 'raison': 'erreur'};
    }
    final f = _achat!.future;
    return f.timeout(const Duration(minutes: 10), onTimeout: () {
      _achat = null;            // la confirmation arrivera plus tard par NVMagasinRecu
      return {'ok': false, 'raison': 'attente'};
    });
  }
}
