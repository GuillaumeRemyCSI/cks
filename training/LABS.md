# Fiche des labs CKS : les dérouler soi-même

Liens vers les énoncés et solutions en anglais sur le fork
[GuillaumeRemyCSI/cks@formation-lfs460](https://github.com/GuillaumeRemyCSI/cks/tree/formation-lfs460).
Tous les labs ont été testés sur Google Cloud (europe-west6) le 2026-11-02 : déploiement, nœuds
`Ready` en Kubernetes 1.35.2 et `check_result` fonctionnent. Les solutions, elles, restent à
dérouler : c'est l'objet de cette fiche.

## Déployer un lab pour soi seul

Avec un fichier de participants qui ne contient que vous :

```bash
echo formateur > /tmp/formateur.txt
```

```bash
cd ~/code/cks && PARTICIPANTS_FILE=/tmp/formateur.txt training/classroom.sh up 107
```

La fiche d'accès (IP du poste de travail et mot de passe) est dans
`training/out/107/formateur.txt`. Comptez 10 à 15 minutes, puis :

```bash
ssh ubuntu@<ip>
```

Sur le poste de travail :

- `tail -f /var/log/cloud-init-output.log` : attendre la fin de l'initialisation ;
- `source ~/.bashrc`, puis `kubectl get nodes` ;
- `check_result` : score et indices (`HINT`) ; `time_left` : temps restant ;
- `ssh <nom-du-nœud>` pour aller sur un nœud (noms donnés par `kubectl get nodes`).

Une fois le lab terminé, détruisez-le :

```bash
cd ~/code/cks && PARTICIPANTS_FILE=/tmp/formateur.txt training/classroom.sh down 107
```

## Vue d'ensemble

| Lab | Thème | Domaine CKS | Chapitres LFS460 | VMs | Durée | Énoncé | Solution | Fait |
|---|---|---|---|---|---|---|---|---|
| 101 | NetworkPolicy, isolation, metadata | Cluster Setup | 6 | 2 | 6 h | [EN][e101] | [EN][s101] | ☐ |
| 102 | CiliumNetworkPolicy L3/L4/L7, Hubble | Cluster Setup | 6 | 2 | 6 h | [EN][e102] | [EN][s102] | ☐ |
| 103 | CIS/kube-bench, Ingress TLS, binaires | Cluster Setup | 2, 4, 6 | 3 | 6 h | [EN][e103] | [EN][s103] | ☐ |
| 104 | RBAC, ServiceAccount, anonymous-auth | Cluster Hardening | 5, 8 | 2 | 6 h | [EN][e104] | [EN][s104] | ☐ |
| 105 | Durcissement de l'OS et du daemon Docker | System Hardening | (hors slides) | 3 | 6 h | [EN][e105] | [EN][s105] | ☐ |
| 106 | AppArmor et seccomp | System Hardening | 7 | 2 | 6 h | [EN][e106] | [EN][s106] | ☐ |
| 107 | Pod Security Admission | Microservice Vulnerabilities | 5 | 2 | 6 h | [EN][e107] | [EN][s107] | ☐ |
| 108 | Kyverno, Gatekeeper, ImagePolicyWebhook | Microservice Vulnerabilities | 4, 5 | 2 | 6 h | [EN][e108] | [EN][s108] | ☐ |
| 109 | Chiffrement des Secrets dans etcd | Microservice Vulnerabilities | 5 | 2 | 6 h | [EN][e109] | [EN][s109] | ☐ |
| 110 | gVisor, WireGuard Cilium, mTLS Istio | Microservice Vulnerabilities | 3, 6 | 3 | 6 h | [EN][e110] | [EN][s110] | ☐ |
| 111 | Analyse d'images, SBOM, supply chain | Supply Chain Security | 3, 7 | 2 | 6 h | [EN][e111] | [EN][s111] | ☐ |
| 112 | Falco, audit logs, filesystem immuable | Monitoring & Runtime | 5, 7, 8 | 2 | 6 h | [EN][e112] | [EN][s112] | ☐ |
| 113 | Montée de version kubeadm 1.35 → 1.36 | Cluster Hardening | 4 (théorie) | 3 | 2 h | [EN][e113] | [EN][s113] | ☐ |
| 114 | Contextes kubeconfig, certificats clients | Cluster Hardening | (hors slides) | 2 | 6 h | [EN][e114] | [EN][s114] | ☐ |
| 115 | Cilium sans kube-proxy, Mutual Auth | Cluster Setup | 6 | 2 | 6 h | [EN][e115] | [EN][s115] | ☐ |

La durée est celle du minuteur `time_left` (après quoi le kubeconfig est retiré), pas le temps
nécessaire : prévoyez plutôt 1 h à 2 h par lab pour le dérouler.

## Détail par lab

### 101 - NetworkPolicy: default-deny, isolation, and cloud metadata

- [Énoncé][e101] · [Solution][s101] · 7 tâches
- Sur GCP, `169.254.169.254` est le serveur de métadonnées GCE : même comportement à observer
  (note dans l'énoncé).
- Testé en entier côté plateforme : DNS, API, métadonnées et `check_result` vérifiés depuis un pod.

### 102 - CiliumNetworkPolicy: L3/L4/L7, DNS-aware egress, and Hubble

- [Énoncé][e102] · [Solution][s102] · 6 tâches
- À dérouler en priorité : Cilium dépend du réseau du cloud.

### 103 - CIS/kube-bench, Secure Ingress TLS, and binary verification

- [Énoncé][e103] · [Solution][s103] · 10 tâches
- Cours : [Chapter 07. CIS Benchmark and kube-bench][c07],
  [Chapter 08. Secure Ingress with TLS][c08],
  [Chapter 09. Insecure component arguments, TLS hardening, and binary verification][c09]
- Cluster à deux nœuds (control-plane + worker). Le script du worker a été corrigé
  (il ne se terminait jamais) : à vérifier que la tâche 10, sur le worker, se passe bien.

### 104 - Restricting access to the Kubernetes API

- [Énoncé][e104] · [Solution][s104] · 12 tâches

### 105 - System Hardening of the OS and Docker daemon security

- [Énoncé][e105] · [Solution][s105] · 10 tâches
- Cours : [Chapter 14. Minimizing host OS footprint and runtime daemon security][c14],
  [Chapter 15. Host least privilege and minimizing external network access][c15]
- VM supplémentaire `docker-host`, avec un daemon Docker volontairement exposé en TCP/2375.

### 106 - AppArmor and seccomp

- [Énoncé][e106] · [Solution][s106] · 9 tâches
- Cours : [Chapter 16. AppArmor][c16], [Chapter 17. seccomp][c17],
  [Chapter 03. Linux security mechanisms under the hood][c03]
- Ubuntu 24.04 embarque AppArmor 4 : vérifier que les profils de la solution se chargent.

### 107 - Pod Security Admission

- [Énoncé][e107] · [Solution][s107] · 7 tâches
- Les labels PSA sont en `v1.35`, la version du cluster et de l'examen.

### 108 - Admission policies with Kyverno

- [Énoncé][e108] · [Solution][s108] · 7 tâches
- Couvre aussi Gatekeeper (tâche 7) et ImagePolicyWebhook (tâche 6), exercices 4.5 et 5.5
  des slides.

### 109 - Encrypting Secrets in etcd and minimal access

- [Énoncé][e109] · [Solution][s109] · 5 tâches

### 110 - gVisor RuntimeClass, Cilium WireGuard, and Istio mTLS

- [Énoncé][e110] · [Solution][s110] · 6 tâches
- Cours : [Chapter 22. Container Runtime Sandbox][c22],
  [Chapter 23. Pod-to-Pod encryption and mTLS][c23]
- Nœud dédié `gvisor` ; à dérouler en priorité (gVisor, WireGuard et Istio dépendent de la VM et
  du réseau).

### 111 - image analysis, static fixes, and supply-chain evidence

- [Énoncé][e111] · [Solution][s111] · 8 tâches
- Les participants utilisent podman en rootless : point à surveiller sur Ubuntu 24.04
  (restrictions AppArmor sur les user namespaces).
- Le plus long à initialiser (téléchargement des outils et des images à scanner).

### 112 - Runtime: Falco, audit logs, and an immutable root filesystem

- [Énoncé][e112] · [Solution][s112] · 10 tâches
- Cours : [Chapter 29. Falco][c29], [Chapter 30. Threat detection][c30],
  [Chapter 31. Container immutability at runtime][c31], [Chapter 32. Kubernetes audit logs][c32],
  [Chapter 26. Supply-chain security][c26]

### 113 - Upgrading a Kubernetes Cluster with kubeadm

- [Énoncé][e113] · [Solution][s113] · 4 tâches
- Cours : [Chapter 13. Upgrading Kubernetes to remediate vulnerabilities][c13]
- Le cluster part de 1.35.2 et se met à jour en 1.36.x. Minuteur de 2 h.
- Script du worker corrigé comme pour le 103.

### 114 - Kubeconfig contexts, client certificates, and API exposure

- [Énoncé][e114] · [Solution][s114] · 4 tâches
- Au démarrage, `kubectl` pointe volontairement sur `staging.cks114.invalid` : c'est l'exercice.

### 115 - Cilium bootstrap, kube-proxy replacement, and Mutual Authentication

- [Énoncé][e115] · [Solution][s115] · 6 tâches
- Au démarrage, CoreDNS est `Pending` : c'est normal, il faut installer Cilium (tâche 1).
- À dérouler en priorité (Cilium sans kube-proxy).

## Ordre suggéré pour vos essais

1. Les labs qui dépendent le plus du cloud : **115, 102, 110**, puis **113**.
2. Ceux qui touchent à l'OS des nœuds (Ubuntu 24.04) : **106, 105, 111, 112**.
3. Les autres : 101, 103, 104, 107, 108, 109, 114.

Si un lab bloque, relevez le message `HINT` de `check_result` et la fin de
`/var/log/cloud-init-output.log` sur la VM concernée.

[e101]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/101/README.MD
[s101]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/101/worker/files/solutions/1.MD
[e102]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/102/README.MD
[s102]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/102/worker/files/solutions/1.MD
[e103]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/103/README.MD
[s103]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/103/worker/files/solutions/1.MD
[e104]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/104/README.MD
[s104]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/104/worker/files/solutions/1.MD
[e105]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/105/README.MD
[s105]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/105/worker/files/solutions/1.MD
[e106]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/106/README.MD
[s106]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/106/worker/files/solutions/1.MD
[e107]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/107/README.MD
[s107]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/107/worker/files/solutions/1.MD
[e108]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/108/README.MD
[s108]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/108/worker/files/solutions/1.MD
[e109]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/109/README.MD
[s109]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/109/worker/files/solutions/1.MD
[e110]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/110/README.MD
[s110]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/110/worker/files/solutions/1.MD
[e111]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/111/README.MD
[s111]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/111/worker/files/solutions/1.MD
[e112]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/112/README.MD
[s112]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/112/worker/files/solutions/1.MD
[e113]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/113/README.MD
[s113]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/113/worker/files/solutions/1.MD
[e114]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/114/README.MD
[s114]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/114/worker/files/solutions/1.MD
[e115]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/115/README.MD
[s115]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/115/worker/files/solutions/1.MD
[c03]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/03/README.md
[c07]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/07/README.md
[c08]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/08/README.md
[c09]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/09/README.md
[c13]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/13/README.md
[c14]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/14/README.md
[c15]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/15/README.md
[c16]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/16/README.md
[c17]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/17/README.md
[c22]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/22/README.md
[c23]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/23/README.md
[c26]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/26/README.md
[c29]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/29/README.md
[c30]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/30/README.md
[c31]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/31/README.md
[c32]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/32/README.md
