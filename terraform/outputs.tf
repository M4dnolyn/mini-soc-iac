output "network_name" {
  description = "Docker network name"
  value       = docker_network.soc.name
}

output "indexer_url" {
  description = "Wazuh Indexer URL (internal)"
  value       = "https://localhost:${var.indexer_port}"
}

output "dashboard_url" {
  description = "Wazuh Dashboard URL"
  value       = "https://localhost:${var.dashboard_port}"
}

output "manager_agent_port" {
  description = "Wazuh Manager agent communication port"
  value       = var.manager_agent_port
}

output "manager_api_port" {
  description = "Wazuh Manager API port"
  value       = var.manager_api_port
}

output "agent_name" {
  description = "Wazuh Agent container name"
  value       = docker_container.agent.name
}

output "containers" {
  description = "List of running container names"
  value = [
    docker_container.indexer.name,
    docker_container.manager.name,
    docker_container.dashboard.name,
    docker_container.agent.name,
  ]
}
