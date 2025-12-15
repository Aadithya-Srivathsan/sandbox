terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# ----------------------------------------------------
# Azure Provider (Sandbox Safe)
# ----------------------------------------------------
provider "azurerm" {
  features {}

  # REQUIRED for Pluralsight Sandbox
  resource_provider_registrations = "none"
}

# ----------------------------------------------------
# Use EXISTING Pluralsight Sandbox Resource Group
# ----------------------------------------------------
data "azurerm_resource_group" "sandbox" {
  name = var.existing_rg_name
}

# ----------------------------------------------------
# Random suffix (Storage account must be globally unique)
# ----------------------------------------------------
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

# ----------------------------------------------------
# Storage Account (Required for Azure Functions)
# ----------------------------------------------------
resource "azurerm_storage_account" "func_storage" {
  name                     = "genaifunc${random_integer.rand.result}"
  resource_group_name      = data.azurerm_resource_group.sandbox.name
  location                 = data.azurerm_resource_group.sandbox.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ----------------------------------------------------
# App Service Plan (Consumption – Sandbox Allowed)
# ----------------------------------------------------
resource "azurerm_service_plan" "func_plan" {
  name                = "genai-func-plan"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  location            = data.azurerm_resource_group.sandbox.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

# ----------------------------------------------------
# Linux Azure Function App (Python 3.10)
# ----------------------------------------------------
resource "azurerm_linux_function_app" "genai_function" {
  name                = "genai-chatbot-${random_integer.rand.result}"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  location            = data.azurerm_resource_group.sandbox.location
  service_plan_id     = azurerm_service_plan.func_plan.id

  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    OPENAI_ENDPOINT          = var.openai_endpoint
    OPENAI_API_KEY           = var.openai_api_key
  }
}
