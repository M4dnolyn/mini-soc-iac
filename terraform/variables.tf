variable "wazuh_version" {
  description = "Wazuh Docker image version tag"
  type        = string
  default     = "4.14.5"
}

variable "network_name" {
  description = "Docker network name for SOC"
  type        = string
  default     = "soc-network"
}

variable "indexer_port" {
  description = "Host port for Wazuh Indexer (OpenSearch)"
  type        = number
  default     = 9200
}

variable "dashboard_port" {
  description = "Host port for Wazuh Dashboard (HTTPS)"
  type        = number
  default     = 443
}

variable "manager_agent_port" {
  description = "Host port for Wazuh Manager agent communication"
  type        = number
  default     = 1514
}

variable "manager_authd_port" {
  description = "Host port for Wazuh Manager authd"
  type        = number
  default     = 1515
}

variable "manager_api_port" {
  description = "Host port for Wazuh Manager API"
  type        = number
  default     = 55000
}

variable "indexer_admin_password" {
  description = "Admin password for Wazuh Indexer"
  type        = string
  sensitive   = true
  default     = "Admin123!"
}

variable "dashboard_password" {
  description = "Password for Wazuh Dashboard UI"
  type        = string
  sensitive   = true
  default     = "Admin123!"
}

variable "api_username" {
  description = "Username for Wazuh Manager API"
  type        = string
  default     = "wazuh-wui"
}

variable "api_password" {
  description = "Password for Wazuh Manager API"
  type        = string
  sensitive   = true
  default     = "W4zuhS3cur3!2026"
}

variable "agent_name" {
  description = "Name for the Wazuh agent container"
  type        = string
  default     = "wazuh-agent"
}
