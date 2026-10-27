# Formation CKS (LFS460) : déployer les labs pour une classe

Adaptations de ce fork par rapport au dépôt amont :

| Sujet | Amont | Ici |
|---|---|---|
| Kubernetes des labs 101-115 | 1.36.0 | **1.35.2**, même mineure que l'examen CKS |
| OS des VMs | Ubuntu 22.04 | **Ubuntu 24.04** |
| Lab 113 (montée de version) | 1.35.4 → 1.36.x | 1.35.2 → 1.36.x (le sujet reste la montée de mineure) |
| Scripts et tests téléchargés par les VMs | `ViktorUJ/cks@master` en dur | dépôt et branche configurables (`CKS_REPO`, `CKS_REPO_REF`) |
| Accès SSH | `0.0.0.0/0` en dur | restreignable à la salle (`CKS_ACCESS_CIDRS`) |
| Droits S3 des VMs | `s3:*` sur tout le bucket du state (states et mots de passe de tous les participants) | lecture (et écriture pour le master) limitée à `config/<participant>/<lab>/` |
| Lien de l'énoncé dans les outputs | README russe | README français |

## Une fois, avant la formation

1. **Publier ce fork.** Les VMs téléchargent au démarrage leurs scripts et les tests de
   `check_result` depuis GitHub : sans fork poussé, elles utiliseraient les versions amont
   (1.36) et les tests échoueraient. Le dépôt doit être public.
2. **Bucket du state Terraform.** Remplacez `backend_bucket` dans
   `terraform/environments/terragrunt.hcl` par un nom à vous (unique au monde). Terragrunt crée
   le bucket et la table DynamoDB s'ils n'existent pas.
3. **Outils** : `terraform`, `terragrunt` v0.73.x (version du runner Docker du projet), `aws`,
   `jq`, `make`.
4. **Configuration** :
   ```bash
   cp training/classroom.env.example training/classroom.env
   cp training/participants.txt.example training/participants.txt
   ```
   puis renseignez `CKS_REPO`, `CKS_REPO_REF`, l'IP de la salle et la liste des participants
   (identifiants courts, pas de données personnelles).
5. **Quotas AWS** (région `eu-central-1`) : un VPC par participant et par lab déployé en même
   temps, alors que le quota par défaut est de **5 VPC par région**. Il faut aussi compter
   4 à 6 vCPU par participant et par lab. Le preflight calcule le besoin et le compare aux quotas :
   ```bash
   training/classroom.sh preflight 101 102
   ```
   Demandez les augmentations plusieurs jours à l'avance.
6. **Répétition générale** : déployez chaque lab prévu pour un seul participant (`p00`
   par exemple), faites-le, puis lancez `check_result`. C'est la seule vraie validation du passage
   en 24.04 / 1.35.2.

## Pendant la formation

```bash
training/classroom.sh up 107            # déploie le lab 107 pour chaque participant
training/classroom.sh access 107        # régénère les fiches d'accès
training/classroom.sh down 107          # détruit les environnements du lab 107
```

`up` vérifie le preflight, déploie `PARALLEL` participants à la fois (comptez 10-15 min par
vague), puis écrit dans `training/out/107/` une fiche `<participant>.txt` par personne (IP, mot de
passe, lien vers l'énoncé) ainsi que `acces.csv`. Ces fichiers contiennent des mots de passe et
ne sont pas versionnés.

Les logs de chaque déploiement sont dans `training/logs/<lab>/<participant>.<action>.log`. Pour
relancer un seul participant en échec :

```bash
USER_ID=p03 ENV_ID=107 TASK=107 make run_cks_task
```

**Coûts** : pensez au `down` en fin de journée. Pour vérifier qu'il ne reste rien :

```bash
make cmdb_get_env_all
```
