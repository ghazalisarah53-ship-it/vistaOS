# VistaOS

Un Linux léger pour vieux PC portables, basé sur Debian 13 avec XFCE et l'installeur Calamares.
Barre des tâches unique en verre bleu, bouton Démarrer en orbe, écran « Bienvenue sur VistaOS »,
thème GRUB bleu et animation de démarrage Plymouth.

Projet indépendant : il n'est affilié ni à Microsoft, ni à HP, ni au projet Debian.
Le nom, le logo, l'orbe et les animations sont originaux.

## Compiler l'ISO

Il faut internet et environ 15 Go libres. Compte 20 à 60 minutes.

```bash
chmod +x build-vistaos.sh
./build-vistaos.sh
```

- Debian / Ubuntu : le build se fait directement (sudo demandé).
- Arch et autres distributions : le script lance tout dans un conteneur Debian 13
  (Docker ou Podman requis, par exemple `sudo pacman -S docker`).

Le résultat est `VistaOS.iso`, à côté du script. Mets-le sur une clé USB avec Balena Etcher
ou `dd`, puis démarre dessus. Teste toujours en mode live avant d'installer, et sauvegarde
tes données : l'installeur peut effacer le disque.

## Configuration requise

Processeur 64 bits, 1 Go de RAM minimum, 2 Go ou plus conseillés.

## Modifier VistaOS

Tout est dans `build-vistaos.sh` : la liste des paquets, les réglages XFCE (`/etc/skel`),
le thème GRUB, l'animation Plymouth, le logo (généré avec ImageMagick) et le branding Calamares.
Change ce que tu veux, relance le script, republie ta version.

## Contribuer

Les améliorations sont les bienvenues : thèmes, corrections, traductions, tests sur d'autres modèles.

## Licence

Les scripts, thèmes et images de ce dépôt sont sous licence MIT (voir LICENSE).
Les logiciels intégrés à l'ISO (Debian, XFCE, Calamares, Firefox, etc.) gardent leurs propres licences.
