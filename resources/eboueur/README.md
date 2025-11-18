# Resource `eboueur`

Script FiveM pour job coopératif éboueur (prototype)

Installation
- Copiez le dossier `eboueur` dans votre dossier `resources` du serveur FiveM.
- Ajoutez `ensure eboueur` dans votre `server.cfg`.

Utilisation
- Ouvrir le panneau: appuyez sur `F6` ou utilisez la commande `/eboueur_ui`.
- Démarrer une mission depuis le panneau.
- Vous devez être dans le camion pour ramasser les poubelles.
- Le script gère XP et niveaux côté serveur (stockage simple dans `eboueur_data.json`).

Notes
- Le script tente de détecter QBCore ou ESX pour restreindre le job aux citoyens. Ajustez la fonction `IsCitizen()` dans `client.lua` si votre serveur utilise un autre système.
- Coordonnées du garage, points de mission et paramètres sont dans `config.lua`.
- Ce script est un prototype et nécessite des adaptations (sécurité, persistance DB, permissions) pour production.

Intégration `qb-clothing`
- Si `qb-clothing` est présent sur le serveur, `eboueur` tentera d'utiliser les events/exports courants pour appliquer la tenue de travail et **sauvegarder automatiquement** la tenue sous le nom `Eboueur` (tentatives best-effort sur les noms d'événements communs). Si votre version de `qb-clothing` utilise un nom d'event/export différent, indiquez-le pour que je l'ajuste.
