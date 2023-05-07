provider "azurerm" {
  features {}
}

variable "resource_group_name" {}
variable "location" {}

module "resource_group" {
  source = "./modules/resource_group"

  resource_group_name = "${terraform.workspace}-${var.resource_group_name}"
  location            = var.location
}
