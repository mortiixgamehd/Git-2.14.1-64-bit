# Documentation : Zones personnalisées

## Création de zones
- Utilisez le panel NUI pour créer une zone personnalisée
- Ajoutez des points (coordonnées X, Y, Z et type de poubelle)
- Sauvegardez la zone, elle sera partagée et persistante côté serveur

## Synchronisation
- Les zones sont synchronisées automatiquement à chaque ouverture du panel
- Tous les joueurs voient la même liste de zones

## Fichier de persistance
- Les zones sont stockées dans `eboueur_zones.json` côté serveur

## Exemple de structure JSON
```json
{
  "MaZone": [
    { "pos": { "x": 123.4, "y": 456.7, "z": 21.0 }, "type": "normal" },
    { "pos": { "x": 124.0, "y": 457.0, "z": 21.0 }, "type": "recycle" }
  ]
}
```

## Personnalisation
- Modifiez ou ajoutez des zones via le panel ou directement dans le fichier JSON
- Redémarrez la ressource pour recharger les zones
