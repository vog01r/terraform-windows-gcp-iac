# 🚀 Guide de démarrage rapide

## ⚡ En 5 minutes chrono !

### 1. Créer un compte GCP (2 min)
1. Aller sur [console.cloud.google.com](https://console.cloud.google.com)
2. Se connecter avec votre email Google
3. Activer la facturation (nécessaire pour les crédits gratuits)

### 2. Créer un compte de service (1 min)
1. Console GCP > IAM et administration > Comptes de service
2. Créer un compte : `terraform-admin`
3. Rôle : `Propriétaire`
4. Créer une clé JSON et la télécharger

### 3. Préparer l'environnement (1 min)
```bash
# Renommer le fichier téléchargé
mv ~/Downloads/your-service-account-key.json key.json

# Cloner le projet
git clone <repository-url>
cd windows_server_administration

# Vérifier la structure
ls -la
# Vous devriez voir : key.json, README.md, terraform/
```

### 4. Déployer (1 min)
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 5. Se connecter
```bash
# Récupérer les infos de connexion
terraform output ssh_connection_info
terraform output server1_password

# Se connecter en SSH
ssh admin@$(terraform output -raw server1_public_ip)
# Mot de passe : WinSrv1-XXXX
```

## 🎯 Résultat attendu

Après 5-10 minutes, vous aurez :
- ✅ 2 serveurs Windows Server 2025
- ✅ Accès SSH et RDP configurés
- ✅ OpenSSH et WinRM installés
- ✅ IIS web server installé
- ✅ Utilisateur `admin` créé

## 🧹 Nettoyage
```bash
terraform destroy
```

## 💰 Coût
- **Gratuit** avec les crédits Google Cloud ($300)
- **~$0.38/heure** si vous payez
- **Détruire après utilisation** pour éviter les coûts

## 🆘 Besoin d'aide ?
- Consulter le [README.md](README.md) pour le guide complet
- Voir [docs/troubleshooting.md](docs/troubleshooting.md) pour les problèmes courants
- Vérifier [docs/deployment.md](docs/deployment.md) pour les détails
