# Guide de déploiement

## 📋 Table des matières

- [Pré-requis](#pré-requis)
- [Configuration initiale](#configuration-initiale)
- [Déploiement](#déploiement)
- [Vérification](#vérification)
- [Connexion aux serveurs](#connexion-aux-serveurs)
- [Désinstallation](#désinstallation)

## Pré-requis

### Logiciels requis

| Logiciel | Version minimale | Installation |
|----------|------------------|--------------|
| **Terraform** | 1.0+ | [Download](https://terraform.io/downloads) |
| **Google Cloud CLI** | 400.0+ | [Installation](https://cloud.google.com/sdk/docs/install) |
| **Client SSH** | - | OpenSSH (Linux/Mac) ou PuTTY (Windows) |
| **Client RDP** | - | mstsc (Windows) ou Remmina (Linux) |

### Compte Google Cloud

1. **Projet GCP** : Créer ou utiliser un projet existant
2. **Service Account** : Créer un compte de service avec les permissions :
   - `Compute Admin`
   - `Service Account User`
3. **Clés JSON** : Télécharger le fichier de clés et le placer dans le projet

### APIs activées

```bash
# Activer les APIs nécessaires
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

## Configuration initiale

### 1. Authentification

```bash
# Méthode 1 : Service Account (recommandée)
export GOOGLE_APPLICATION_CREDENTIALS="key.json"

# Méthode 2 : gcloud auth
gcloud auth application-default login
```

### 2. Vérification des quotas

```bash
# Vérifier les quotas disponibles
gcloud compute project-info describe --project=YOUR_PROJECT_ID

# Quotas requis minimum :
# - vCPU : 4 (2 instances × 2 vCPU)
# - IPs externes : 2
# - Réseaux VPC : 1
```

### 3. Configuration des variables (optionnel)

```bash
# Créer un fichier terraform.tfvars
cat > terraform/terraform.tfvars << EOF
machine_type = "e2-standard-2"
boot_disk_gb = 50
image_name = "windows-server-2025-dc-v20250913"
image_project = "windows-cloud"
EOF
```

## Déploiement

### 1. Initialisation

```bash
# Naviguer vers le répertoire terraform
cd terraform

# Initialiser Terraform
terraform init

# Vérifier la configuration
terraform validate
```

### 2. Planification

```bash
# Voir le plan d'exécution
terraform plan

# Plan avec variables personnalisées
terraform plan -var="machine_type=e2-standard-4"
```

### 3. Déploiement

```bash
# Déploiement avec confirmation
terraform apply

# Déploiement automatique
terraform apply -auto-approve

# Déploiement avec variables
terraform apply -var-file="production.tfvars"
```

### 4. Déploiement par étapes (optionnel)

```bash
# 1. Créer le réseau
terraform apply -target=google_compute_network.windows_vpc
terraform apply -target=google_compute_subnetwork.windows_subnet

# 2. Créer les règles de pare-feu
terraform apply -target=google_compute_firewall.allow_rdp
terraform apply -target=google_compute_firewall.allow_ssh
terraform apply -target=google_compute_firewall.allow_winrm

# 3. Créer les serveurs
terraform apply -target=google_compute_instance.windows_server_1
terraform apply -target=google_compute_instance.windows_server_2
```

## Vérification

### 1. État des ressources

```bash
# Voir l'état actuel
terraform show

# Lister les ressources
terraform state list

# Vérifier une ressource spécifique
terraform state show google_compute_instance.windows_server_1
```

### 2. Outputs

```bash
# Afficher tous les outputs
terraform output

# Outputs spécifiques
terraform output server1_public_ip
terraform output ssh_connection_info
terraform output rdp_connection_info
```

### 3. Vérification GCP

```bash
# Lister les instances
gcloud compute instances list --filter="name~windows-server"

# Vérifier les règles de pare-feu
gcloud compute firewall-rules list --filter="name~allow-"

# Vérifier les réseaux
gcloud compute networks list --filter="name~vpc-windows"
```

## Connexion aux serveurs

### 1. Récupération des informations

```bash
# Informations de connexion complètes
terraform output windows_connection_info

# Informations SSH
terraform output ssh_connection_info

# Informations RDP
terraform output rdp_connection_info

# Mots de passe
terraform output server1_password
terraform output server2_password
```

### 2. Connexion SSH

```bash
# Connexion au serveur 1
ssh admin@$(terraform output -raw server1_public_ip)

# Connexion au serveur 2
ssh admin@$(terraform output -raw server2_public_ip)

# Avec mot de passe (non recommandé)
sshpass -p "$(terraform output -raw server1_password)" ssh admin@$(terraform output -raw server1_public_ip)
```

### 3. Connexion RDP

```bash
# Commande RDP pour serveur 1
mstsc /v:$(terraform output -raw server1_public_ip)

# Commande RDP pour serveur 2
mstsc /v:$(terraform output -raw server2_public_ip)
```

### 4. Connexion WinRM (PowerShell)

```powershell
# Test de connectivité
Test-WSMan -ComputerName $(terraform output -raw server1_public_ip) -Port 5985

# Connexion PowerShell à distance
Enter-PSSession -ComputerName $(terraform output -raw server1_public_ip) -Credential (Get-Credential)
```

## Désinstallation

### 1. Destruction complète

```bash
# Plan de destruction
terraform plan -destroy

# Destruction avec confirmation
terraform destroy

# Destruction automatique
terraform destroy -auto-approve
```

### 2. Destruction sélective

```bash
# Détruire uniquement les serveurs
terraform destroy -target=google_compute_instance.windows_server_1
terraform destroy -target=google_compute_instance.windows_server_2

# Détruire le réseau (attention : détruit tout)
terraform destroy -target=google_compute_network.windows_vpc
```

### 3. Nettoyage

```bash
# Supprimer les fichiers d'état
rm terraform.tfstate*

# Supprimer le cache Terraform
rm -rf .terraform/

# Supprimer les fichiers générés
rm -f ../ansible/vars/terraform_output.json
```

## Dépannage courant

### Erreurs d'authentification

```bash
# Vérifier les credentials
gcloud auth application-default print-access-token

# Re-authentifier
gcloud auth application-default login

# Vérifier le fichier de clés
cat key.json | jq .
```

### Erreurs de quotas

```bash
# Vérifier les quotas
gcloud compute project-info describe --project=YOUR_PROJECT_ID

# Demander une augmentation
gcloud compute regions describe us-central1
```

### Problèmes de réseau

```bash
# Vérifier les règles de pare-feu
gcloud compute firewall-rules list --filter="name~allow-"

# Tester la connectivité
gcloud compute ssh windows-server-1 --zone=us-central1-a
```

### Scripts PowerShell non exécutés

```bash
# Vérifier les logs de démarrage
gcloud compute instances get-serial-port-output windows-server-1 --zone=us-central1-a

# Redémarrer l'instance
gcloud compute instances reset windows-server-1 --zone=us-central1-a
```

## Commandes utiles

### Terraform

```bash
# Graph des dépendances
terraform graph | dot -Tpng > dependencies.png

# Format du code
terraform fmt

# Validation
terraform validate

# Refresh de l'état
terraform refresh
```

### Google Cloud

```bash
# Informations sur le projet
gcloud config get-value project

# Changer de projet
gcloud config set project YOUR_PROJECT_ID

# Informations sur les quotas
gcloud compute project-info describe
```

### Monitoring

```bash
# Logs de démarrage en temps réel
gcloud compute instances tail-serial-port-output windows-server-1 --zone=us-central1-a

# Statut des instances
gcloud compute instances describe windows-server-1 --zone=us-central1-a
```

## Variables d'environnement

```bash
# Configuration via variables d'environnement
export TF_VAR_machine_type="e2-standard-4"
export TF_VAR_boot_disk_gb="100"
export TF_VAR_image_name="windows-server-2025-dc-v20250913"

# Puis exécuter
terraform apply
```

## Bonnes pratiques

### Sécurité
- Utiliser des clés SSH au lieu des mots de passe
- Restreindre les sources IP dans les règles de pare-feu
- Activer les logs de pare-feu
- Configurer un bastion host

### Gestion d'état
- Utiliser un backend distant (GCS, S3)
- Activer le verrouillage d'état
- Utiliser des workspaces pour les environnements

### Monitoring
- Configurer des alertes de budget
- Activer les logs de monitoring
- Implémenter des sauvegardes automatiques
