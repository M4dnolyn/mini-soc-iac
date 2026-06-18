locals {
  wazuh_tag       = var.wazuh_version
  indexer_url     = "https://wazuh-indexer:9200"
  indexer_creds   = "${var.api_username}:${var.indexer_admin_password}"
  agent_name      = var.agent_name
}

resource "docker_network" "soc" {
  name = var.network_name
}

# Images

resource "docker_image" "indexer" {
  name = "wazuh/wazuh-indexer:${local.wazuh_tag}"
}

resource "docker_image" "manager" {
  name = "wazuh/wazuh-manager:${local.wazuh_tag}"
}

resource "docker_image" "dashboard" {
  name = "wazuh/wazuh-dashboard:${local.wazuh_tag}"
}

resource "docker_image" "agent" {
  name = "wazuh/wazuh-agent:${local.wazuh_tag}"
}

# Volumes

resource "docker_volume" "indexer_data" {
  name = "wazuh-indexer-data"
}

resource "docker_volume" "manager_data" {
  name = "wazuh-manager-data"
}

resource "docker_volume" "dashboard_data" {
  name = "wazuh-dashboard-data"
}

# Wazuh Indexer

resource "docker_container" "indexer" {
  name  = "wazuh-indexer"
  image = docker_image.indexer.name

  networks_advanced {
    name = docker_network.soc.name
  }

  ports {
    internal = 9200
    external = var.indexer_port
    protocol = "tcp"
  }

  volumes {
    volume_name    = docker_volume.indexer_data.name
    container_path = "/var/lib/wazuh-indexer"
  }

  env = [
    "INDEXER_PASSWORD=admin",
    "DISABLE_INSTALL_DEMO_CONFIG=false",
    "DISABLE_SECURITY_PLUGIN=false",
  ]

  healthcheck {
    test         = ["CMD", "curl", "-sfk", "-u", "admin:admin", "https://localhost:9200"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 10
    start_period = "60s"
  }

  restart = "unless-stopped"
}

# Wazuh Manager

resource "docker_container" "manager" {
  name  = "wazuh-manager"
  image = docker_image.manager.name

  networks_advanced {
    name = docker_network.soc.name
  }

  ports {
    internal = 1514
    external = var.manager_agent_port
    protocol = "tcp"
  }
  ports {
    internal = 1515
    external = var.manager_authd_port
    protocol = "tcp"
  }
  ports {
    internal = 55000
    external = var.manager_api_port
    protocol = "tcp"
  }

  volumes {
    volume_name    = docker_volume.manager_data.name
    container_path = "/var/ossec/data"
  }

  env = [
    "INDEXER_URL=${local.indexer_url}",
    "INDEXER_USERNAME=admin",
    "INDEXER_PASSWORD=admin",
    "FILEBEAT_SSL_VERIFY_MODE=disable",
    "API_USERNAME=${var.api_username}",
    "API_PASSWORD=${var.api_password}",
  ]

  restart = "unless-stopped"

  depends_on = [docker_container.indexer]
}

# Wazuh Dashboard

resource "docker_container" "dashboard" {
  name  = "wazuh-dashboard"
  image = docker_image.dashboard.name

  networks_advanced {
    name = docker_network.soc.name
  }

  ports {
    internal = 443
    external = var.dashboard_port
    protocol = "tcp"
  }

  volumes {
    host_path      = abspath("${path.root}/../conf")
    container_path = "/usr/share/wazuh-dashboard/config"
  }

  volumes {
    volume_name    = docker_volume.dashboard_data.name
    container_path = "/usr/share/wazuh-dashboard/data"
  }

  env = [
    "OPENSEARCH_HOSTS=${local.indexer_url}",
    "OPENSEARCH_USERNAME=admin",
    "OPENSEARCH_PASSWORD=admin",
    "OPENSEARCH_SSL_VERIFICATION_MODE=none",
    "SERVER_NAME=wazuh-dashboard",
    "SERVER_HOST=0.0.0.0",
    "SERVER_PORT=443",
    "WAZUH_API_URL=https://wazuh-manager",
    "API_USERNAME=${var.api_username}",
    "API_PASSWORD=${var.api_password}",
  ]

  restart = "unless-stopped"

  depends_on = [docker_container.indexer]
}

# Wazuh Agent (Client)

resource "docker_container" "agent" {
  name  = local.agent_name
  image = docker_image.agent.name

  hostname = local.agent_name

  networks_advanced {
    name = docker_network.soc.name
  }

  privileged = true

  env = [
    "WAZUH_MANAGER_IP=wazuh-manager",
    "WAZUH_MANAGER_PORT=1514",
    "WAZUH_PROTOCOL=tcp",
    "WAZUH_AGENT_NAME=client-01",
  ]

  restart = "unless-stopped"

  depends_on = [docker_container.manager]
}
