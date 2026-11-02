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
| Cloud | AWS uniquement | AWS ou **Google Cloud** (`CKS_CLOUD=gcp`, voir plus bas) |

## Une fois, avant la formation

Les étapes 2, 3 et 5 ci-dessous concernent AWS. Sur Google Cloud, suivez plutôt la section
[Sur Google Cloud](#sur-google-cloud).

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

### VMs vierges des exercices officiels LFS460

Les exercices du support de cours se font sur des VMs Ubuntu 24.04 vierges, où les participants
installent eux-mêmes Kubernetes avec les scripts de la LF :

```bash
training/classroom.sh up lfs460-single     # chapitres 2-3 : un nœud 'single'
training/classroom.sh down lfs460-single   # à la fin du chapitre 3 (« two fresh nodes »)
training/classroom.sh up lfs460-cluster    # chapitre 4 et suivants : nœuds 'cp' et 'worker'
```

Chaque participant reçoit des t3.large (2 vCPU / 8 Go) avec l'utilisateur `student`
(sudo sans mot de passe), un mot de passe SSH commun à ses nœuds et un trafic libre entre ses
nœuds. Ces VMs n'ont aucun rôle IAM et ne téléchargent rien depuis le fork. Vous
communiquez vous-même les identifiants de téléchargement des fichiers du cours (cm.lf.training).

### Fonctionnement commun

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

## Sur Google Cloud

Avec `CKS_CLOUD="gcp"` dans `training/classroom.env`, les mêmes commandes (`preflight`, `up`,
`access`, `down`) déploient les labs 101-115 et les VMs LFS460 sur Google Cloud. Les examens
blancs (`mock/01-04`) restent sur AWS.

### Mise en place

1. **Projet** : créez-en un dédié à la formation, avec la facturation activée, puis activez
   l'API Compute Engine :
   ```bash
   gcloud services enable compute.googleapis.com --project <id-du-projet>
   ```
2. **Identifiants pour Terraform** :
   ```bash
   gcloud auth application-default login
   ```
3. **Configuration** : renseignez `CKS_GCP_PROJECT` et `CKS_GCP_STATE_BUCKET` (le bucket du state
   est créé par `classroom.sh up` s'il n'existe pas), ainsi que `CKS_REPO` / `CKS_REPO_REF` comme sur AWS.
4. **Outils** : `terraform`, `terragrunt` v0.73.x, `gcloud`, `jq`.
5. **Quotas** : le preflight compare le besoin aux quotas du projet (réseaux VPC, règles de
   pare-feu) et de la région (vCPU, IP externes). Sur un projet récent, le quota d'**IP externes**
   est souvent de 8 par région, soit à peine 3 participants sur un lab. Demandez l'augmentation
   à l'avance (IAM et administration > Quotas).

### Différences avec AWS

- **Pas d'identifiants cloud sur les VMs** : aucune n'a de compte de service. Le master partage
  le kubeconfig et la commande `kubeadm join` par SSH (clé propre au lab) au lieu de S3.
- **Types de machine** : t3.small → e2-small, t3.medium → e2-medium, t3.large → e2-standard-2
  (mêmes vCPU et mémoire).
- **Noms des nœuds** : les instances s'appellent `cks-<participant>-<lab>-…` ; les nœuds
  Kubernetes portent ce nom (au lieu de `ip-10-…` sur AWS).
- **Lab 101** : `169.254.169.254` est le serveur de métadonnées GCE ; les vérifications sont
  identiques (accessibilité réseau), voir la note dans l'énoncé.
- **Scripts de démarrage** : ceux de `terraform/modules/gcp_*/template/` sont dérivés des scripts
  AWS. Si le dépôt amont modifie ces derniers, régénérez-les :
  ```bash
  python3 terraform/modules/gcp_common/derive_templates.py terraform/modules
  ```

### Relancer un participant, vérifier le nettoyage

Sur Google Cloud, le Makefile n'est pas utilisé : pour relancer un seul participant, utilisez un
fichier de participants qui ne contient que lui :

```bash
echo p03 > /tmp/p03.txt
PARTICIPANTS_FILE=/tmp/p03.txt training/classroom.sh up 107
```

Pour vérifier qu'il ne reste aucune VM :

```bash
gcloud compute instances list --project <id-du-projet> --filter="name~^cks-"
```
