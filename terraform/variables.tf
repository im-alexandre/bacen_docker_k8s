variable "aws_region" {
  type        = string
  description = "Região da sub-rede e da AMI."
}

variable "expected_account_id" {
  type        = string
  description = "Conta AWS autorizada para o laboratório."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "Informe os 12 dígitos da conta de laboratório."
  }
}

variable "ami_id" {
  type        = string
  description = "AMI oficial Ubuntu Server 24.04 LTS amd64 nesta região."

  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ami_id))
    error_message = "Informe o ID da AMI oficial nesta região."
  }
}

variable "instructor_cidr" {
  type        = string
  description = "IPv4 público atual do instrutor, com sufixo /32."

  validation {
    condition     = can(cidrnetmask(var.instructor_cidr)) && endswith(var.instructor_cidr, "/32")
    error_message = "Informe um único IPv4 público no formato x.x.x.x/32."
  }
}

variable "ssh_public_key_path" {
  type        = string
  description = "Caminho da chave pública relativo à pasta terraform."
  default     = "../.execucao/bacen-dk.pub"
}
