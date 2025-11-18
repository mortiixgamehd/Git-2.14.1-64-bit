# Eboueur-QBCore

Script FiveM QBCore : Job coopératif éboueur avancé

-
## Aperçu
![Panel de mission](docs/panel.png)

## Fonctionnalités
- Missions avancées par zone (Mission Row, Mirror Park, Place des Cubes, Sandy Shores)
- Création et sauvegarde de zones personnalisées (panel NUI, persistance serveur)
- Types de poubelles (classique, recyclage, toxique) avec XP et récompenses
- Progression, niveaux, XP, panel interactif
- Tenue de travail, garage de spawn camion
- Restriction du job aux citoyens
- Synchronisation automatique des zones personnalisées entre joueurs

## Installation
1. Copier le dossier `eboueur` dans `resources` de votre serveur FiveM
2. Ajouter dans `server.cfg` :
	```
	ensure eboueur
	```
3. Démarrer le serveur

## Utilisation
- Ouvrir le panneau : touche `F6` ou commande `/eboueur_ui`
- Choisir une zone ou créer une zone personnalisée
- Démarrer la mission, nettoyer les points indiqués
- Prendre/retirer la tenue au garage

## Fichiers importants
- `client.lua` : logique client, missions, tenues, NUI
- `server.lua` : XP, niveaux, stockage, zones personnalisées
- `config.lua` : configuration des missions, garage, tenues
- `html/` : interface NUI (panel, JS, CSS)
- `eboueur_data.json` : progression XP/levels
- `eboueur_zones.json` : stockage des zones personnalisées

## Personnalisation
- Ajoutez/modifiez les zones dans le panel NUI
- Les zones sont synchronisées et sauvegardées côté serveur
- Adaptez les types de poubelles et récompenses dans `config.lua`

## Intégration QBCore / qb-clothing
- Compatible QBCore (job citoyen, tenues)
- Si `qb-clothing` est présent, la tenue est sauvegardée automatiquement

## Support
Pour toute demande d’adaptation, bug ou ajout de fonctionnalité, ouvrez une issue sur GitHub ou contactez mortiixgamehd.

## Licence
Ce script est fourni à titre d’exemple et peut être adapté librement pour usage personnel ou communautaire.
