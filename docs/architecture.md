# Architecture détaillée

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Composants réseau](#composants-réseau)
- [Instances de calcul](#instances-de-calcul)
- [Sécurité et pare-feu](#sécurité-et-pare-feu)
- [Scripts de configuration](#scripts-de-configuration)
- [Flux de données](#flux-de-données)

## Vue d'ensemble

L'infrastructure déployée par ce projet Terraform crée un environnement Windows Server isolé sur Google Cloud Platform avec les composants suivants :

### Composants principaux

```mermaid
graph LR
    subgraph "Terraform Configuration"
        TF[Terraform State]
        VARS[Variables]
        OUTPUTS[Outputs]
    end
    
    subgraph "Google Cloud Platform"
        VPC[VPC Network]
        SUBNET[Subnet]
        FW[Firewall Rules]
        IP[Public IPs]
        VM1[Windows Server 1]
        VM2[Windows Server 2]
    end
    
    subgraph "Services Windows"
        SSH[OpenSSH]
        RDP[RDP]
        WINRM[WinRM]
        IIS[IIS]
    end
    
    TF --> VPC
    VARS --> VM1
    VARS --> VM2
    VPC --> SUBNET
    SUBNET --> VM1
    SUBNET --> VM2
    FW --> VM1
    FW --> VM2
    IP --> VM1
    IP --> VM2
    
    VM1 --> SSH
    VM1 --> RDP
    VM1 --> WINRM
    VM1 --> IIS
    VM2 --> SSH
    VM2 --> RDP
    VM2 --> WINRM
    VM2 --> IIS
```

## Composants réseau

### VPC et Subnet

| Composant | Configuration | Détails |
|-----------|---------------|---------|
| **VPC** | `vpc-windows-{random_id}` | Réseau privé isolé |
| **Subnet** | `subnet-windows-{random_id}` | Sous-réseau dans us-central1 |
| **CIDR** | `192.168.20.0/24` | 254 adresses IP disponibles |
| **Région** | `us-central1` | Région Google Cloud |

### Adressage IP

| Serveur | IP Privée | IP Publique | Usage |
|---------|-----------|-------------|-------|
| **Server 1** | `192.168.20.10` | Dynamique | Serveur principal |
| **Server 2** | `192.168.20.11` | Dynamique | Serveur secondaire |

## Instances de calcul

### Configuration des serveurs

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| **Image** | `windows-server-2025-dc-v20250913` | Windows Server 2025 Datacenter |
| **Machine Type** | `e2-standard-2` | 2 vCPU, 8GB RAM |
| **Disque** | `50GB SSD` | Disque de démarrage persistant |
| **Zone** | `us-central1-a` | Zone de disponibilité |

### Ressources allouées

```mermaid
pie title Répartition des ressources
    "vCPU" : 4
    "RAM (GB)" : 16
    "Stockage (GB)" : 100
    "IPs publiques" : 2
```

## Sécurité et pare-feu

### Règles de pare-feu configurées

| Règle | Ports | Source | Cible | Description |
|-------|-------|--------|-------|-------------|
| **RDP** | `3389/tcp` | `0.0.0.0/0` | `windows-server` | Remote Desktop |
| **SSH** | `22/tcp` | `0.0.0.0/0` | `windows-server` | Secure Shell |
| **WinRM** | `5985,5986/tcp` | `0.0.0.0/0` | `windows-server` | Windows Remote Management |
| **Web** | `80,443/tcp` | `0.0.0.0/0` | `windows-server` | HTTP/HTTPS |
| **Internal** | `all` | `192.168.20.0/24` | `windows-server` | Communication interne |

### Flux de trafic

```mermaid
graph TD
    INTERNET[Internet] --> FW[Firewall Rules]
    
    FW --> RDP_PORT[Port 3389 - RDP]
    FW --> SSH_PORT[Port 22 - SSH]
    FW --> WINRM_PORT[Port 5985/5986 - WinRM]
    FW --> WEB_PORT[Port 80/443 - HTTP/HTTPS]
    
    RDP_PORT --> WS1[Windows Server 1]
    RDP_PORT --> WS2[Windows Server 2]
    SSH_PORT --> WS1
    SSH_PORT --> WS2
    WINRM_PORT --> WS1
    WINRM_PORT --> WS2
    WEB_PORT --> WS1
    WEB_PORT --> WS2
    
    WS1 <--> WS2
```

## Scripts de configuration

### Scripts PowerShell de démarrage

Chaque serveur exécute un script PowerShell au premier démarrage qui configure :

#### 1. Création d'utilisateur
```powershell
$username = "admin"
$password = "WinSrv{1|2}-{random_id.hex}"
net user $username $password /add
net localgroup administrators $username /add
```

#### 2. Configuration des services
- **RDP** : Activation du Remote Desktop
- **WinRM** : Configuration pour l'accès distant
- **OpenSSH** : Installation et configuration du serveur SSH
- **IIS** : Installation d'Internet Information Services

#### 3. Configuration de sécurité
- Désactivation de l'UAC pour WinRM
- Configuration du pare-feu Windows
- Génération des clés SSH

### Ordre d'exécution

```mermaid
sequenceDiagram
    participant VM as Instance Windows
    participant PS as PowerShell Script
    participant SVC as Services Windows
    participant FW as Firewall Windows
    
    VM->>PS: Démarrage
    PS->>PS: Créer utilisateur admin
    PS->>SVC: Activer RDP
    PS->>SVC: Configurer WinRM
    PS->>SVC: Installer OpenSSH
    PS->>SVC: Installer IIS
    PS->>FW: Configurer règles pare-feu
    PS->>VM: Configuration terminée
```

## Flux de données

### Déploiement Terraform

```mermaid
graph TD
    START[terraform apply] --> INIT[Initialisation]
    INIT --> RANDOM[Génération IDs aléatoires]
    RANDOM --> VPC[Création VPC]
    VPC --> SUBNET[Création Subnet]
    SUBNET --> FW[Création règles pare-feu]
    FW --> IP[Réservation IPs publiques]
    IP --> VM1[Création Server 1]
    IP --> VM2[Création Server 2]
    VM1 --> SCRIPT1[Exécution script PowerShell]
    VM2 --> SCRIPT2[Exécution script PowerShell]
    SCRIPT1 --> READY1[Server 1 prêt]
    SCRIPT2 --> READY2[Server 2 prêt]
    READY1 --> OUTPUT[Génération outputs]
    READY2 --> OUTPUT
```

### Accès aux serveurs

```mermaid
graph LR
    USER[Utilisateur] --> CHOICE{Type d'accès}
    
    CHOICE -->|Graphique| RDP[RDP Client]
    CHOICE -->|Ligne de commande| SSH[SSH Client]
    CHOICE -->|PowerShell| WINRM[WinRM Client]
    CHOICE -->|Web| BROWSER[Navigateur Web]
    
    RDP --> WS1[Windows Server 1]
    RDP --> WS2[Windows Server 2]
    SSH --> WS1
    SSH --> WS2
    WINRM --> WS1
    WINRM --> WS2
    BROWSER --> WS1
    BROWSER --> WS2
```

## Points d'attention

### Sécurité
- ⚠️ **Accès Internet ouvert** : Tous les ports sont accessibles depuis `0.0.0.0/0`
- ⚠️ **WinRM non chiffré** : Configuration `AllowUnencrypted="true"`
- ⚠️ **Mots de passe en clair** : Visibles dans les outputs Terraform

### Performance
- **Instances e2-standard-2** : Optimisées pour les charges de travail générales
- **Disques SSD** : Performances élevées pour les opérations I/O
- **Réseau** : Bande passante élevée entre les serveurs

### Disponibilité
- **Zone unique** : Déploiement dans `us-central1-a` uniquement
- **Pas de load balancer** : Aucune répartition de charge
- **Pas de sauvegarde automatique** : Snapshots manuels requis

## Évolutions possibles

### Haute disponibilité
- Déploiement multi-zone
- Load balancer pour la répartition de charge
- Sauvegardes automatiques

### Sécurité renforcée
- Bastion host pour l'accès
- VPN ou accès privé
- Chiffrement des communications

### Monitoring
- Stack de monitoring (Prometheus/Grafana)
- Logs centralisés
- Alertes automatiques
