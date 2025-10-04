output "server1_public_ip" {
  value       = google_compute_instance.windows_server_1.network_interface[0].access_config[0].nat_ip
  description = "Adresse IP publique du serveur Windows 1"
}

output "server1_private_ip" {
  value       = google_compute_instance.windows_server_1.network_interface[0].network_ip
  description = "Adresse IP privée du serveur Windows 1"
}

output "server2_public_ip" {
  value       = google_compute_instance.windows_server_2.network_interface[0].access_config[0].nat_ip
  description = "Adresse IP publique du serveur Windows 2"
}

output "server2_private_ip" {
  value       = google_compute_instance.windows_server_2.network_interface[0].network_ip
  description = "Adresse IP privée du serveur Windows 2"
}

output "rdp_connection_info" {
  value = {
    server1 = {
      public_ip = google_compute_instance.windows_server_1.network_interface[0].access_config[0].nat_ip
      rdp_url   = "mstsc /v:${google_compute_instance.windows_server_1.network_interface[0].access_config[0].nat_ip}"
    }
    server2 = {
      public_ip = google_compute_instance.windows_server_2.network_interface[0].access_config[0].nat_ip
      rdp_url   = "mstsc /v:${google_compute_instance.windows_server_2.network_interface[0].access_config[0].nat_ip}"
    }
  }
  description = "Informations de connexion RDP pour les serveurs Windows"
}

output "network_info" {
  value = {
    vpc_name    = local.network_name
    subnet_name = local.subnet_name
    cidr_range  = "192.168.20.0/24"
  }
  description = "Informations sur le réseau VPC"
}

output "server1_password" {
  value       = "WinSrv1-${random_id.network.hex}"
  description = "Mot de passe du serveur Windows 1"
}

output "server2_password" {
  value       = "WinSrv2-${random_id.network.hex}"
  description = "Mot de passe du serveur Windows 2"
}

output "windows_connection_info" {
  value = {
    server1 = {
      username = "admin"
      password = "WinSrv1-${random_id.network.hex}"
      public_ip = google_compute_instance.windows_server_1.network_interface[0].access_config[0].nat_ip
      private_ip = google_compute_instance.windows_server_1.network_interface[0].network_ip
      rdp_command = "mstsc /v:${google_compute_instance.windows_server_1.network_interface[0].access_config[0].nat_ip}"
    }
    server2 = {
      username = "admin"
      password = "WinSrv2-${random_id.network.hex}"
      public_ip = google_compute_instance.windows_server_2.network_interface[0].access_config[0].nat_ip
      private_ip = google_compute_instance.windows_server_2.network_interface[0].network_ip
      rdp_command = "mstsc /v:${google_compute_instance.windows_server_2.network_interface[0].access_config[0].nat_ip}"
    }
  }
  description = "Informations complètes de connexion aux serveurs Windows avec utilisateur personnalisé"
}

output "password_retrieval_instructions" {
  value = {
    method1 = "Console Google Cloud: Compute Engine > VM instances > [nom_serveur] > Afficher le mot de passe"
    method2 = "gcloud CLI: gcloud compute instances get-serial-port-output [nom_serveur] --zone=us-central1-a"
    note = "Windows Server 2025 ne génère pas automatiquement de mot de passe. Utilisez la console Google Cloud."
  }
  description = "Instructions pour récupérer les mots de passe Windows"
}

output "firewall_rules" {
  value = {
    rdp_ports    = ["3389"]
    web_ports    = ["80", "443"]
    winrm_ports  = ["5985", "5986"]
    ssh_ports    = ["22"]
    internal_all = "all"
  }
  description = "Ports ouverts par les règles de pare-feu"
}

output "ssh_connection_info" {
  value = {
    server1 = {
      hostname = data.google_compute_instance.windows_server_1_info.network_interface[0].access_config[0].nat_ip
      username = "admin"
      password = "WinSrv1-${random_id.network.hex}"
      ssh_command = "ssh admin@${data.google_compute_instance.windows_server_1_info.network_interface[0].access_config[0].nat_ip}"
    }
    server2 = {
      hostname = data.google_compute_instance.windows_server_2_info.network_interface[0].access_config[0].nat_ip
      username = "admin"
      password = "WinSrv2-${random_id.network.hex}"
      ssh_command = "ssh admin@${data.google_compute_instance.windows_server_2_info.network_interface[0].access_config[0].nat_ip}"
    }
  }
  description = "Informations de connexion SSH aux serveurs Windows"
}