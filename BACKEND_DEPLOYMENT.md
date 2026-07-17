# Déploiement du backend partagé

Les appels `activateChildDevice`, `reportChildAlert`, `updateChildDeviceMetadata` et `analyzeChildNotification` sont requis par l'application enfant. Ils doivent être déployés dans le même projet Firebase que l'application parent : `control-parental-5f115`.

## Source canonique

Ne maintenez pas deux versions divergentes de `functions/index.js`. La copie du présent dépôt doit être fusionnée dans le dépôt parent avant que celui-ci redevienne la source de déploiement. Un patch de comparaison est fourni dans `integration/parent-functions.patch`.

## Configuration

Depuis la racine de ce projet :

```bash
firebase use control-parental-5f115
firebase functions:secrets:set GEMINI_API_KEY
```

Définissez ensuite `GEMINI_MODEL` avec un modèle disponible pour le projet. Le fichier `functions/.env.example` documente uniquement le nom du paramètre ; aucune clé réelle ne doit être enregistrée dans le dépôt.

## Installation et validation

```bash
cd functions
npm ci
node --check index.js
cd ..
firebase deploy --only functions
```

Après déploiement, validez au minimum :

- un token enfant valide est consommé une seule fois ;
- un deuxième appareil ne peut pas rejouer le token ;
- un UID non associé ne peut ni envoyer une alerte ni mettre à jour les métadonnées ;
- une alerte crée un document et une seule notification parentale ;
- l'absence de configuration Gemini produit une réponse sûre sans clé côté client.
