variable "group" {
  type        = string
  description = "the team making use of this resource"
  default     = "federated-engineers"
}

variable "team" {
  type    = string
  default = "elite"
}

variable "service" {
  type    = string
  default = "lambda"
}

variable "use_case" {
  type    = string
  default = "muchen-autos"
}

variable "environment" {
  type    = string
  default = "developement"
}
