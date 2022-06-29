variable "resource_group_name" {
  default = "rg-createbyTF"
}

variable "location_name" {
  default = "uksouth"
}

variable "network_name" {
  default = "vnet1"
}

variable "subnet_name" {
  default = "subnet1"
}

variable "num_maquinas" {
  default = 3
}

variable "availability-zones" {
type = list(string)
default = [
"1", "2", "3",
"1", "2", "3",
]
}