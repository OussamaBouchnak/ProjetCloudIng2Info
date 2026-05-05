variable "db_username" {
  type        = string
  description = "Username for the RDS PostgreSQL database"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Password for the RDS PostgreSQL database"
}

variable "db_name" {
  type        = string
  description = "Name of the RDS PostgreSQL database"
  default     = "chatdb"
}
