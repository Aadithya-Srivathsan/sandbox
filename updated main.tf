main.tf 

provider "azurerm" {
  features {}
}

# --------------------------------------------------
# Use EXISTING Pluralsight Sandbox Resource Group
# --------------------------------------------------
data "azurerm_resource_group" "sandbox" {
  name = var.existing_rg_name
}

# Random suffix for global uniqueness
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# --------------------------------------------------
# Storage Account (Required for Function App)
# --------------------------------------------------
resource "azurerm_storage_account" "func_storage" {
  name                     = "genaifunc${random_integer.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.sandbox.name
  location                 = data.azurerm_resource_group.sandbox.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# --------------------------------------------------
# App Service Plan (Consumption)
# --------------------------------------------------
resource "azurerm_service_plan" "func_plan" {
  name                = "genai-func-plan"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  os_type             = "Linux"
  sku_name            = "Y1"
}

# --------------------------------------------------
# Zip the Azure Function code
# (function_app is INSIDE terraform/)
# --------------------------------------------------
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function_app"
  output_path = "${path.module}/function_app.zip"
}

# --------------------------------------------------
# Storage container to hold the ZIP
# --------------------------------------------------
resource "azurerm_storage_container" "code" {
  name                  = "function-code"
  storage_account_name  = azurerm_storage_account.func_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "function_zip" {
  name                   = "function_app.zip"
  storage_account_name   = azurerm_storage_account.func_storage.name
  storage_container_name = azurerm_storage_container.code.name
  type                   = "Block"
  source                 = data.archive_file.function_zip.output_path
}

# --------------------------------------------------
# SAS token so Function App can read the ZIP
# --------------------------------------------------
data "azurerm_storage_account_sas" "zip_sas" {
  connection_string = azurerm_storage_account.func_storage.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
  }

  start  = "2024-01-01"
  expiry = "2030-01-01"
}

# --------------------------------------------------
# Azure Linux Function App (Python)
# --------------------------------------------------
resource "azurerm_linux_function_app" "genai_function" {
  name                = "genai-chatbot-${random_integer.suffix.result}"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
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

    # Run-from-package (ZIP)
    WEBSITE_RUN_FROM_PACKAGE = "https://${azurerm_storage_account.func_storage.name}.blob.core.windows.net/${azurerm_storage_container.code.name}/${azurerm_storage_blob.function_zip.name}${data.azurerm_storage_account_sas.zip_sas.sas}"

    # OpenAI settings
    OPENAI_ENDPOINT = var.openai_endpoint
    OPENAI_API_KEY  = var.openai_api_key
  }
}
-----------------------------------------------------------------------------------------------------------

terraform.tfvars

# --------------------------------------------------
# Pluralsight Sandbox Resource Group
# (DO NOT change or create a new one)
# --------------------------------------------------
existing_rg_name = "1-4d3cc949-playground-sandbox"

# --------------------------------------------------
# Azure OpenAI Configuration
# (Pre-created outside the sandbox)
# --------------------------------------------------
openai_endpoint = "https://<your-openai-resource-name>.openai.azure.com"
openai_api_key  = "<YOUR_AZURE_OPENAI_API_KEY>"
