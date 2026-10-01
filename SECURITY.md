# Security policy

Ce dépôt est public.

Ne jamais commiter :
- IBM entitlement key ;
- token IBM License Service ;
- mot de passe ;
- kubeconfig ;
- clé privée ;
- fichier `.env` contenant des credentials ;
- snapshot/evidence contenant des secrets.

Une valeur d'entitlement non vide a été trouvée dans l'arbre public pendant O8 et retirée de `main`.

La suppression de `main` ne supprime pas l'historique Git. Toute valeur historiquement commitée doit être considérée compromise et révoquée/rotatée si elle a été utilisable.

Les credentials nécessaires doivent être injectés au runtime via variables d'environnement, Ansible Vault ou un secret store adapté.
