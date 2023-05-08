# Sign in to Azure
# az login --use-device-code

# Check if prod.sensitive.tfvars file exists
if (Test-Path -Path "prod.sensitive.tfvars") {
  # Read prod.sensitive.tfvars file
  $TfvarsContent = Get-Content -Path "prod.sensitive.tfvars"

  # Parse key-value pairs
  $Tfvars = @{}
  foreach ($Line in $TfvarsContent) {
      if ($Line -match '^\s*(\S+)\s*=\s*"(.*)"\s*$') {
          $Key, $Value = $Matches[1], $Matches[2]
          $Tfvars[$Key] = $Value
      }
  }
} else {
  # Prompt user for input
  $ResourceGroupName = Read-Host -Prompt 'Enter the backend resource group name'
  $StorageAccountName = Read-Host -Prompt 'Enter the backend storage account name'
  $ContainerName = Read-Host -Prompt 'Enter the backend container name'

  # Create prod.sensitive.tfvars file with user input
  $TfvarsContent = @"
backend_resource_group_name  = "$ResourceGroupName"
backend_storage_account_name = "$StorageAccountName"
backend_container_name       = "$ContainerName"
"@
  Set-Content -Path "prod.sensitive.tfvars" -Value $TfvarsContent

  # Parse the created prod.sensitive.tfvars file
  $Tfvars = @{}
  foreach ($Line in ($TfvarsContent -split "`n")) {
      if ($Line -match '^\s*(\S+)\s*=\s*"(.*)"\s*$') {
          $Key, $Value = $Matches[1], $Matches[2]
          $Tfvars[$Key] = $Value
      }
  }
}

# Set up variables from prod.sensitive.tfvars
$ResourceGroupName = $Tfvars["backend_resource_group_name"]
$Location = "EastUS"
$StorageAccountName = $Tfvars["backend_storage_account_name"]
$ContainerName = $Tfvars["backend_container_name"]

# Create a resource group
az group create --name $ResourceGroupName --location $Location

# Create a storage account
az storage account create --resource-group $ResourceGroupName --name $StorageAccountName --sku Standard_LRS --encryption-services blob

# Retrieve the storage account key
$StorageAccountKey = (az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" --output tsv)

# Create a storage container
az storage container create --name $ContainerName --account-name $StorageAccountName --account-key $StorageAccountKey

# Generate backend.tf with the backend configuration
$BackendTfContent = @"
terraform {
  backend "azurerm" {
    resource_group_name  = "$ResourceGroupName"
    storage_account_name = "$StorageAccountName"
    container_name       = "$ContainerName"
    key                  = "terraform.tfstate"
    access_key           = "$StorageAccountKey"
  }
}
"@

Set-Content -Path "backend.tf" -Value $BackendTfContent