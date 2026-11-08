// Le rideau de démarrage (8 novembre 2026, demande de Karamo) : dès que l'on touche l'icône, le logo de NEURAVID
// et le mot NEURAVID s'affichent tout de suite, pendant que la page se charge (plus d'écran vide).
// Il disparaît en fondu quand la page est peinte : l'accueil prend alors le relais avec le même logo (son « lever
// de rideau »), puis ses phrases. Aucun texte à traduire ici : seulement le logo et le nom.
import 'package:flutter/material.dart';

class Rideau extends StatelessWidget {
  const Rideau({super.key});

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.of(context).size.width * 0.52;
    final cote = largeur > 220 ? 220.0 : largeur;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0xFF2A0D4C), Color(0xFF140834), Color(0xFF07041A)],
          stops: [0, 0.42, 1],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(cote * 0.22),
              child: Image.asset(
                'assets/web/icones/nv-512.png',
                width: cote,
                height: cote,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, erreur, pile) => SizedBox(width: cote, height: cote),
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFF2EE6C5), Color(0xFF9B6BFF), Color(0xFFFF3D9A)],
              ).createShader(r),
              child: const Text(
                'NEURAVID',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
