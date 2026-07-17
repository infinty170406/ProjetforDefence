# Runbook — rotation et retrait des secrets exposés

Les fichiers `keystore_base64.txt` et `google_services_base64.txt`, ainsi que les archives `android.zip` et `lib.zip`, ont déjà été suivis par Git. Les ignorer ne les retire pas de l'historique : toute clé ou configuration qu'ils contiennent doit être considérée compromise.

## Actions à réaliser avant une nouvelle publication

1. Générer un nouveau keystore de signature dans un coffre ou un poste sécurisé ; ne pas réutiliser l'ancien certificat.
2. Enregistrer le nouveau certificat auprès de Google Play (upload key) et mettre à jour la chaîne de signature/release CI. Si l'application est déjà publiée, suivre la procédure Play App Signing pour une rotation de l'upload key.
3. Révoquer et recréer toute clé/API Firebase-Google éventuellement contenue dans les fichiers ; limiter les nouvelles clés par package Android + SHA-1/SHA-256 et par API.
4. Placer le keystore et les quatre valeurs de `android/key.properties` dans le gestionnaire de secrets CI. Le fichier `android/key.properties` est local et ignoré ; partir de `android/key.properties.example`.
5. Retirer les quatre artefacts de l'index avec `git rm --cached <fichier>` (après avoir sauvegardé tout élément utile hors dépôt), puis réécrire l'historique avec `git filter-repo` ou l'outil validé par l'équipe. Forcer ensuite la mise à jour de la branche et demander aux collaborateurs de recloner.
6. Activer une analyse de secrets dans CI et une règle de pré-commit pour empêcher une nouvelle fuite.

Ne pas publier une release avant la fin des étapes 1 à 4. La purge d'historique doit être coordonnée : elle réécrit les commits et affecte tous les clones et pull requests.
