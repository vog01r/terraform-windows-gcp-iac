# Dépannage

## 📋 Table des matières

- [Problèmes de déploiement](#problèmes-de-déploiement)
- [Problèmes de connectivité](#problèmes-de-connectivité)
- [Problèmes de configuration](#problèmes-de-configuration)
- [Problèmes de performance](#problèmes-de-performance)
- [Commandes de diagnostic](#commandes-de-diagnostic)
- [Solutions d'urgence](#solutions-durgence)

## Problèmes de déploiement

### Erreurs d'authentification

#### Problème : Fichier de clés manquant
```
Error: Error loading credentials: open ../key.json: no such file or directory
```

**Solutions** :
```bash
# 1. Vérifier l'existence du fichier
ls -la ../key.json

# 2. Vérifier les permissions
chmod 600 ../key.json

# 3. Vérifier le contenu
cat ../key.json | jq .

# 4. Re-authentifier avec gcloud
gcloud auth application-default login
```

#### Problème : Permissions insuffisantes
```
Error: Required 'compute.instances.create' permission for 'projects/level-surfer-473817-p5'
```

**Solutions** :
```bash
# 1. Vérifier les rôles du service account
gcloud projects get-iam-policy level-surfer-473817-p5

# 2. Ajouter les rôles nécessaires
gcloud projects add-iam-policy-binding level-surfer-473817-p5 \
    --member="serviceAccount:YOUR_SERVICE_ACCOUNT@level-surfer-473817-p5.iam.gserviceaccount.com" \
    --role="roles/compute.admin"
```

### Erreurs de quotas

#### Problème : Quota vCPU dépassé
```
Error: Quota 'CPUS' exceeded. Limit: 24.0 in region us-central1.
```

**Solutions** :
```bash
# 1. Vérifier les quotas actuels
gcloud compute project-info describe --project=level-surfer-473817-p5

# 2. Vérifier l'utilisation
gcloud compute instances list --filter="zone:us-central1"

# 3. Demander une augmentation de quota
# Via la console GCP : IAM & Admin > Quotas
```

#### Problème : Quota IPs externes dépassé
```
Error: Quota 'EXTERNAL_ADDRESSES' exceeded. Limit: 8.0 in region us-central1.
```

**Solutions** :
```bash
# 1. Libérer des IPs inutilisées
gcloud compute addresses list --filter="status:RESERVED"

# 2. Supprimer les IPs inutilisées
gcloud compute addresses delete ADDRESS_NAME --region=us-central1
```

### Erreurs d'API

#### Problème : API non activée
```
Error: API [compute.googleapis.com] not enabled
```

**Solutions** :
```bash
# 1. Activer l'API Compute Engine
gcloud services enable compute.googleapis.com

# 2. Vérifier les APIs activées
gcloud services list --enabled

# 3. Activer toutes les APIs nécessaires
gcloud services enable compute.googleapis.com cloudresourcemanager.googleapis.com
```

### Erreurs d'image

#### Problème : Image Windows non trouvée
```
Error: The resource 'projects/windows-cloud/global/images/family/windows-server-2025-dc' was not found
```

**Solutions** :
```bash
# 1. Lister les images disponibles
gcloud compute images list --project=windows-cloud --filter="family:windows-server-2025-dc"

# 2. Utiliser l'image exacte
# Modifier variables.tf :
# image_name = "windows-server-2025-dc-v20250913"
```

## Problèmes de connectivité

### SSH ne fonctionne pas

#### Diagnostic
```bash
# 1. Vérifier le statut de l'instance
gcloud compute instances describe windows-server-1 --zone=us-central1-a

# 2. Vérifier les logs de démarrage
gcloud compute instances get-serial-port-output windows-server-1 --zone=us-central1-a

# 3. Tester la connectivité réseau
telnet $(terraform output -raw server1_public_ip) 22

# 4. Vérifier les règles de pare-feu
gcloud compute firewall-rules list --filter="name~allow-ssh"
```

#### Solutions
```bash
# 1. Redémarrer l'instance pour réexécuter les scripts
gcloud compute instances reset windows-server-1 --zone=us-central1-a

# 2. Se connecter via gcloud compute ssh (bypass des règles de pare-feu)
gcloud compute ssh windows-server-1 --zone=us-central1-a

# 3. Vérifier le service SSH depuis l'instance
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-Service sshd"
```

### RDP ne fonctionne pas

#### Diagnostic
```bash
# 1. Vérifier les règles de pare-feu RDP
gcloud compute firewall-rules list --filter="name~allow-rdp"

# 2. Tester la connectivité
telnet $(terraform output -raw server1_public_ip) 3389

# 3. Vérifier le service RDP
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-Service TermService"
```

#### Solutions
```bash
# 1. Redémarrer le service RDP
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Restart-Service TermService"

# 2. Vérifier la configuration RDP
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name fDenyTSConnections"
```

### WinRM ne fonctionne pas

#### Diagnostic
```powershell
# 1. Tester WinRM depuis Windows
Test-WSMan -ComputerName $(terraform output -raw server1_public_ip) -Port 5985

# 2. Vérifier la configuration WinRM
winrm get winrm/config

# 3. Vérifier le service WinRM
Get-Service WinRM
```

#### Solutions
```powershell
# 1. Reconfigurer WinRM
winrm quickconfig -q -force

# 2. Vérifier les listeners
winrm enumerate winrm/config/listener

# 3. Redémarrer le service
Restart-Service WinRM
```

## Problèmes de configuration

### Scripts PowerShell non exécutés

#### Diagnostic
```bash
# 1. Vérifier les logs de démarrage
gcloud compute instances get-serial-port-output windows-server-1 --zone=us-central1-a --port=1

# 2. Vérifier les logs en temps réel
gcloud compute instances tail-serial-port-output windows-server-1 --zone=us-central1-a

# 3. Vérifier les logs Windows
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-EventLog -LogName System -Newest 10"
```

#### Solutions
```bash
# 1. Redémarrer l'instance pour réexécuter les scripts
gcloud compute instances reset windows-server-1 --zone=us-central1-a

# 2. Exécuter manuellement les scripts
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="powershell -ExecutionPolicy Bypass -File C:\Windows\Temp\metadata_script.ps1"
```

### Mots de passe incorrects

#### Diagnostic
```bash
# 1. Vérifier le format des mots de passe
terraform output server1_password
terraform output server2_password

# 2. Vérifier l'ID réseau utilisé
terraform output -raw network_name

# 3. Format attendu : WinSrv1-{random_id.hex}
# Exemple : WinSrv1-3e28
```

#### Solutions
```bash
# 1. Se connecter via gcloud compute ssh pour réinitialiser le mot de passe
gcloud compute ssh windows-server-1 --zone=us-central1-a

# 2. Réinitialiser le mot de passe
net user admin "NouveauMotDePasse123!"

# 3. Vérifier l'utilisateur
net user admin
```

### Services Windows non démarrés

#### Diagnostic
```bash
# 1. Vérifier le statut des services
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-Service sshd, WinRM, TermService"

# 2. Vérifier les services en erreur
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-Service | Where-Object {$_.Status -ne 'Running'}"
```

#### Solutions
```bash
# 1. Démarrer les services manuellement
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Start-Service sshd; Start-Service WinRM; Start-Service TermService"

# 2. Configurer le démarrage automatique
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Set-Service -Name sshd -StartupType Automatic; Set-Service -Name WinRM -StartupType Automatic"
```

## Problèmes de performance

### Instances lentes

#### Diagnostic
```bash
# 1. Vérifier l'utilisation des ressources
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-Process | Sort-Object CPU -Descending | Select-Object -First 10"

# 2. Vérifier l'utilisation mémoire
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory"
```

#### Solutions
```bash
# 1. Redimensionner l'instance
terraform apply -var="machine_type=e2-standard-4"

# 2. Optimiser les services
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-Service | Where-Object {$_.StartType -eq 'Automatic' -and $_.Status -eq 'Stopped'} | Start-Service"
```

### Problèmes de réseau

#### Diagnostic
```bash
# 1. Tester la connectivité interne
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Test-NetConnection -ComputerName 192.168.20.11 -Port 22"

# 2. Vérifier la configuration réseau
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-NetIPAddress"
```

#### Solutions
```bash
# 1. Vérifier les règles de pare-feu internes
gcloud compute firewall-rules list --filter="name~allow-internal"

# 2. Redémarrer les services réseau
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Restart-NetAdapter -Name '*'"
```

## Commandes de diagnostic

### Vérification de l'état Terraform

```bash
# État des ressources
terraform state list

# Détails d'une ressource
terraform state show google_compute_instance.windows_server_1

# Graph des dépendances
terraform graph

# Validation de la configuration
terraform validate

# Format du code
terraform fmt
```

### Vérification GCP

```bash
# Instances en cours d'exécution
gcloud compute instances list --filter="name~windows-server"

# Règles de pare-feu
gcloud compute firewall-rules list --filter="name~allow-"

# Réseaux VPC
gcloud compute networks list --filter="name~vpc-windows"

# Quotas du projet
gcloud compute project-info describe --project=level-surfer-473817-p5
```

### Vérification de connectivité

```bash
# Test de connectivité SSH
nc -zv $(terraform output -raw server1_public_ip) 22

# Test de connectivité RDP
nc -zv $(terraform output -raw server1_public_ip) 3389

# Test de connectivité WinRM
nc -zv $(terraform output -raw server1_public_ip) 5985

# Test de connectivité HTTP
curl -I http://$(terraform output -raw server1_public_ip)
```

### Logs et monitoring

```bash
# Logs de démarrage
gcloud compute instances get-serial-port-output windows-server-1 --zone=us-central1-a

# Logs en temps réel
gcloud compute instances tail-serial-port-output windows-server-1 --zone=us-central1-a

# Logs Windows
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-EventLog -LogName System -Newest 20"

# Logs d'application
gcloud compute ssh windows-server-1 --zone=us-central1-a --command="Get-EventLog -LogName Application -Newest 20"
```

## Solutions d'urgence

### Redémarrage des serveurs

```bash
# Redémarrage via gcloud
gcloud compute instances reset windows-server-1 --zone=us-central1-a
gcloud compute instances reset windows-server-2 --zone=us-central1-a

# Redémarrage via Terraform
terraform apply -replace="google_compute_instance.windows_server_1"
terraform apply -replace="google_compute_instance.windows_server_2"
```

### Recréation complète

```bash
# Destruction et recréation
terraform destroy -auto-approve
terraform apply -auto-approve
```

### Récupération d'accès

```bash
# Connexion via gcloud compute ssh (bypass des règles de pare-feu)
gcloud compute ssh windows-server-1 --zone=us-central1-a

# Réinitialisation des mots de passe via PowerShell
net user admin "NouveauMotDePasse123!"

# Vérification de l'accès
net user admin
```

### Sauvegarde d'urgence

```bash
# Créer un snapshot de l'instance
gcloud compute disks snapshot windows-server-1 --zone=us-central1-a --snapshot-names=backup-$(date +%Y%m%d-%H%M%S)

# Lister les snapshots
gcloud compute snapshots list --filter="name~backup-"
```

## Checklist de dépannage

### Problème de déploiement
- [ ] Vérifier l'authentification GCP
- [ ] Vérifier les quotas disponibles
- [ ] Vérifier les APIs activées
- [ ] Vérifier la configuration Terraform

### Problème de connectivité
- [ ] Vérifier le statut des instances
- [ ] Vérifier les règles de pare-feu
- [ ] Tester la connectivité réseau
- [ ] Vérifier les services Windows

### Problème de configuration
- [ ] Vérifier les logs de démarrage
- [ ] Vérifier l'exécution des scripts PowerShell
- [ ] Vérifier les mots de passe
- [ ] Vérifier les services Windows

### Problème de performance
- [ ] Vérifier l'utilisation des ressources
- [ ] Vérifier la configuration réseau
- [ ] Vérifier les services en cours d'exécution
- [ ] Considérer le redimensionnement

## Ressources utiles

### Documentation officielle
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Cloud Compute Engine](https://cloud.google.com/compute/docs)
- [Windows Server 2025](https://docs.microsoft.com/en-us/windows-server/)

### Outils de diagnostic
- [Terraform Graph](https://www.terraform.io/docs/cli/commands/graph.html)
- [gcloud CLI](https://cloud.google.com/sdk/gcloud)
- [PowerShell](https://docs.microsoft.com/en-us/powershell/)

### Support communautaire
- [Terraform Community](https://discuss.hashicorp.com/c/terraform-core)
- [Google Cloud Community](https://cloud.google.com/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/terraform)
