resource "random_pet" "uid" {
  length = 1
}

resource "random_id" "network" {
  byte_length = 2
}

locals {
  uid = format("win-%s", random_pet.uid.id)

  servers = {
    server1 = {
      uid = local.uid
      name = "windows-server-1"
      private_ip = "192.168.20.10"
    }
    server2 = {
      uid = local.uid
      name = "windows-server-2"
      private_ip = "192.168.20.11"
    }
  }

  network_name = format("vpc-windows-%s", random_id.network.hex)
  subnet_name  = format("subnet-windows-%s", random_id.network.hex)
}

# Création du réseau VPC pour Windows
resource "google_compute_network" "windows_vpc" {
  name                    = local.network_name
  auto_create_subnetworks = false
}

# Création du sous-réseau pour Windows
resource "google_compute_subnetwork" "windows_subnet" {
  name          = local.subnet_name
  ip_cidr_range = "192.168.20.0/24"
  region        = "us-central1"
  network       = google_compute_network.windows_vpc.id
}

# Règles de pare-feu pour RDP (Remote Desktop Protocol)
resource "google_compute_firewall" "allow_rdp" {
  name    = format("allow-rdp-%s", random_id.network.hex)
  network = google_compute_network.windows_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["windows-server"]
}

# Règles de pare-feu pour HTTP/HTTPS
resource "google_compute_firewall" "allow_http_https" {
  name    = format("allow-web-%s", random_id.network.hex)
  network = google_compute_network.windows_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["windows-server"]
}

# Règles de pare-feu pour la communication interne entre serveurs
resource "google_compute_firewall" "allow_internal" {
  name    = format("allow-internal-%s", random_id.network.hex)
  network = google_compute_network.windows_vpc.id

  allow {
    protocol = "all"
  }

  source_ranges = ["192.168.20.0/24"]
  target_tags   = ["windows-server"]
}

# Règles de pare-feu pour WinRM (Windows Remote Management)
resource "google_compute_firewall" "allow_winrm" {
  name    = format("allow-winrm-%s", random_id.network.hex)
  network = google_compute_network.windows_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["5985", "5986"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["windows-server"]
}

# Règles de pare-feu pour SSH (OpenSSH)
resource "google_compute_firewall" "allow_ssh" {
  name    = format("allow-ssh-%s", random_id.network.hex)
  network = google_compute_network.windows_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["windows-server"]
}

# Adresses IP publiques pour chaque serveur
resource "google_compute_address" "public_ip" {
  for_each     = local.servers
  name         = format("public-ip-%s", each.key)
  region       = "us-central1"
  address_type = "EXTERNAL"
}

# Serveur Windows 1
resource "google_compute_instance" "windows_server_1" {
  name         = local.servers.server1.name
  machine_type = var.machine_type
  zone         = "us-central1-a"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/${var.image_project}/global/images/${var.image_name}"
      size  = var.boot_disk_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.windows_subnet.id
    network_ip = local.servers.server1.private_ip

    access_config {
      nat_ip = google_compute_address.public_ip["server1"].address
    }
  }

  metadata = {
    windows-startup-script-ps1 = <<-EOT
      # Configuration initiale du serveur Windows
      Write-Host "Configuration du serveur Windows 1..."
      
      # Créer un utilisateur personnalisé
      $username = "admin"
      $password = "WinSrv1-${random_id.network.hex}"
      
      # Créer l'utilisateur local
      net user $username $password /add
      net localgroup administrators $username /add
      
      # Activer RDP
      Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
      Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
      
      # Configurer WinRM pour l'accès distant
      winrm quickconfig -q -force
      winrm set winrm/config/service/auth '@{Basic="true"}'
      winrm set winrm/config/service '@{AllowUnencrypted="true"}'
      winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
      winrm set winrm/config/winrs '@{MaxProcessesPerShell="25"}'
      winrm set winrm/config/winrs '@{MaxConcurrentUsers="10"}'
      winrm set winrm/config/winrs '@{MaxShellsPerUser="5"}'
      
      # Configurer WinRM pour accepter les connexions depuis n'importe quelle IP
      winrm set winrm/config/service '@{MaxConcurrentOperations="4294967295"}'
      winrm set winrm/config/service '@{MaxConcurrentOperationsPerUser="1500"}'
      winrm set winrm/config/service '@{MaxConnections="300"}'
      
      # Désactiver UAC pour WinRM
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
      
      # Redémarrer le service WinRM
      Restart-Service WinRM
      
      # Installer et configurer OpenSSH Server
      Write-Host "Installation d'OpenSSH Server..."
      
      # Installer OpenSSH Server via Windows Features
      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
      
      # Démarrer et configurer le service OpenSSH
      Start-Service sshd
      Set-Service -Name sshd -StartupType 'Automatic'
      
      # Configurer le pare-feu Windows pour SSH
      New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
      
      # Configurer OpenSSH pour accepter les connexions
      $sshdConfig = @"
# Configuration OpenSSH pour Windows
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

HostKey __PROGRAMDATA__/ssh/ssh_host_rsa_key
HostKey __PROGRAMDATA__/ssh/ssh_host_ecdsa_key
HostKey __PROGRAMDATA__/ssh/ssh_host_ed25519_key

# Configuration de l'authentification
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
PermitRootLogin no

# Configuration des utilisateurs
AllowUsers admin
AllowGroups administrators

# Configuration de la session
Subsystem sftp sftp-server.exe
"@
      
      # Écrire la configuration SSH
      $sshdConfig | Out-File -FilePath "C:\ProgramData\ssh\sshd_config" -Encoding UTF8
      
      # Redémarrer le service SSH
      Restart-Service sshd
      
      Write-Host "OpenSSH Server installé et configuré"
      
      # Installer des fonctionnalités Windows
      Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Logging, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Dyn-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Cert-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-App-Dev, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-WebSockets, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service
      
      Write-Host "Utilisateur $username créé avec le mot de passe $password"
      Write-Host "Configuration terminée pour le serveur Windows 1"
    EOT
  }

  tags = ["windows-server"]

  depends_on = [
    google_compute_firewall.allow_rdp,
    google_compute_firewall.allow_http_https,
    google_compute_firewall.allow_internal,
    google_compute_firewall.allow_winrm,
    google_compute_firewall.allow_ssh
  ]
}

# Serveur Windows 2
resource "google_compute_instance" "windows_server_2" {
  name         = local.servers.server2.name
  machine_type = var.machine_type
  zone         = "us-central1-a"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/${var.image_project}/global/images/${var.image_name}"
      size  = var.boot_disk_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.windows_subnet.id
    network_ip = local.servers.server2.private_ip

    access_config {
      nat_ip = google_compute_address.public_ip["server2"].address
    }
  }

  metadata = {
    windows-startup-script-ps1 = <<-EOT
      # Configuration initiale du serveur Windows
      Write-Host "Configuration du serveur Windows 2..."
      
      # Créer un utilisateur personnalisé
      $username = "admin"
      $password = "WinSrv2-${random_id.network.hex}"
      
      # Créer l'utilisateur local
      net user $username $password /add
      net localgroup administrators $username /add
      
      # Activer RDP
      Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
      Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
      
      # Configurer WinRM pour l'accès distant
      winrm quickconfig -q -force
      winrm set winrm/config/service/auth '@{Basic="true"}'
      winrm set winrm/config/service '@{AllowUnencrypted="true"}'
      winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
      winrm set winrm/config/winrs '@{MaxProcessesPerShell="25"}'
      winrm set winrm/config/winrs '@{MaxConcurrentUsers="10"}'
      winrm set winrm/config/winrs '@{MaxShellsPerUser="5"}'
      
      # Configurer WinRM pour accepter les connexions depuis n'importe quelle IP
      winrm set winrm/config/service '@{MaxConcurrentOperations="4294967295"}'
      winrm set winrm/config/service '@{MaxConcurrentOperationsPerUser="1500"}'
      winrm set winrm/config/service '@{MaxConnections="300"}'
      
      # Désactiver UAC pour WinRM
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
      
      # Redémarrer le service WinRM
      Restart-Service WinRM
      
      # Installer et configurer OpenSSH Server
      Write-Host "Installation d'OpenSSH Server..."
      
      # Installer OpenSSH Server via Windows Features
      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
      
      # Démarrer et configurer le service OpenSSH
      Start-Service sshd
      Set-Service -Name sshd -StartupType 'Automatic'
      
      # Configurer le pare-feu Windows pour SSH
      New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
      
      # Configurer OpenSSH pour accepter les connexions
      $sshdConfig = @"
# Configuration OpenSSH pour Windows
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

HostKey __PROGRAMDATA__/ssh/ssh_host_rsa_key
HostKey __PROGRAMDATA__/ssh/ssh_host_ecdsa_key
HostKey __PROGRAMDATA__/ssh/ssh_host_ed25519_key

# Configuration de l'authentification
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
PermitRootLogin no

# Configuration des utilisateurs
AllowUsers admin
AllowGroups administrators

# Configuration de la session
Subsystem sftp sftp-server.exe
"@
      
      # Écrire la configuration SSH
      $sshdConfig | Out-File -FilePath "C:\ProgramData\ssh\sshd_config" -Encoding UTF8
      
      # Redémarrer le service SSH
      Restart-Service sshd
      
      Write-Host "OpenSSH Server installé et configuré"
      
      # Installer des fonctionnalités Windows
      Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Logging, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Dyn-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Cert-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-App-Dev, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-WebSockets, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service
      
      Write-Host "Utilisateur $username créé avec le mot de passe $password"
      Write-Host "Configuration terminée pour le serveur Windows 2"
    EOT
  }

  tags = ["windows-server"]

  depends_on = [
    google_compute_firewall.allow_rdp,
    google_compute_firewall.allow_http_https,
    google_compute_firewall.allow_internal,
    google_compute_firewall.allow_winrm,
    google_compute_firewall.allow_ssh
  ]
}

# Génération de mots de passe pour les serveurs Windows
resource "random_password" "windows_server_1_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "random_password" "windows_server_2_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Variables locales pour les mots de passe (non-sensibles)
locals {
  server1_password = random_password.windows_server_1_password.result
  server2_password = random_password.windows_server_2_password.result
}

# Récupération des mots de passe via l'API alternative
data "google_compute_instance" "windows_server_1_info" {
  name = google_compute_instance.windows_server_1.name
  zone = google_compute_instance.windows_server_1.zone
}

data "google_compute_instance" "windows_server_2_info" {
  name = google_compute_instance.windows_server_2.name
  zone = google_compute_instance.windows_server_2.zone
}

# Génération du fichier d'inventaire Ansible pour Windows (optionnel)
resource "local_file" "ansible_inventory" {
  count = 0  # Désactivé pour l'instant, peut être réactivé si nécessaire
  content = templatefile(
    "${path.module}/../ansible/templates/inventory.ini.tftpl",
    {
      servers = local.servers
      server1_public_ip  = google_compute_instance.windows_server_1.network_interface[0].access_config[0].nat_ip
      server1_private_ip = google_compute_instance.windows_server_1.network_interface[0].network_ip
      server2_public_ip  = google_compute_instance.windows_server_2.network_interface[0].access_config[0].nat_ip
      server2_private_ip = google_compute_instance.windows_server_2.network_interface[0].network_ip
    }
  )

  filename = "${path.module}/../ansible/inventory/generated.ini"

  depends_on = [
    google_compute_instance.windows_server_1,
    google_compute_instance.windows_server_2
  ]
}

# Génération du fichier JSON avec les outputs Terraform
resource "local_file" "terraform_outputs_json" {
  content = jsonencode({
    server1_public_ip  = google_compute_instance.windows_server_1.network_interface[0].access_config[0].nat_ip
    server1_private_ip = google_compute_instance.windows_server_1.network_interface[0].network_ip
    server2_public_ip  = google_compute_instance.windows_server_2.network_interface[0].access_config[0].nat_ip
    server2_private_ip = google_compute_instance.windows_server_2.network_interface[0].network_ip
    network_name       = local.network_name
    subnet_name        = local.subnet_name
  })

  filename = "${path.module}/../ansible/vars/terraform_output.json"

  depends_on = [
    google_compute_instance.windows_server_1,
    google_compute_instance.windows_server_2
  ]
}

output "network_name" {
  value = local.network_name
}

output "subnet_name" {
  value = local.subnet_name
}