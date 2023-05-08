$Regions = @(
    "East US",
    "East US 2",
    "Central US",
    "North Central US",
    "South Central US",
    "West US",
    "West US 2",
    "West US 3",
    "West Central US"
)

# Sign in to Azure
$IsLoggedIn = $null -ne (az account show --output json | ConvertFrom-Json)
if (-not $IsLoggedIn) {
    az login --use-device-code
}
function Read-ResourceGroupNameFromUser {
  do {
      $Name = Read-Host -Prompt 'Enter the backend resource group name'
      if (-not (Test-ResourceGroupName $Name)) {
          Write-Host "Invalid resource group name. It must be 1-90 characters long, alphanumeric, and can include underscores, periods, and hyphens."
      }
  } while (-not (Test-ResourceGroupName $Name))
  return $Name
}

function Read-StorageAccountNameFromUser {
  do {
      $Name = Read-Host -Prompt 'Enter the backend storage account name'
      if (-not (Test-StorageAccountName $Name)) {
          Write-Host "Invalid storage account name. It must be between 3 and 24 characters in length and use numbers and lower-case letters only."
      }
  } while (-not (Test-StorageAccountName $Name))
  return $Name
}

function Read-ContainerNameFromUser {
  do {
      $Name = Read-Host -Prompt 'Enter the backend container name'
      if (-not (Test-ContainerName $Name)) {
          Write-Host "Invalid container name. It must be 3-63 characters long, alphanumeric, and can include hyphens. It must start and end with an alphanumeric character."
      }
  } while (-not (Test-ContainerName $Name))
  return $Name
}

function Test-ResourceGroupName($Name) {
    return ($Name -match '^[a-zA-Z0-9._-]{1,90}$')
}

function Test-StorageAccountName($Name) {
    return ($Name -match '^[a-z0-9]{3,24}$')
}

function Test-ContainerName($Name) {
    return ($Name -match '^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$')
}

function Remove-ResourceGroup($ResourceGroupName) {
    az group delete --name $ResourceGroupName --yes --no-wait
    Write-Host "❌ Removed Resource Group: $ResourceGroupName" -ForegroundColor Red
}

function Remove-StorageAccount($ResourceGroupName, $StorageAccountName) {
    az storage account delete --name $StorageAccountName --resource-group $ResourceGroupName --yes
    Write-Host "❌ Removed Storage Account: $StorageAccountName" -ForegroundColor Red
}

# Functions for creating Azure resources
function New-AzureStorageAccount {
  param (
      [string]$ResourceGroupName,
      [string]$StorageAccountName,
      [string]$Location
  )

  Write-Host "Creating storage account... $StorageAccountName" -NoNewline

  try {
      $StorageAccount = az storage account create --resource-group $ResourceGroupName --name $StorageAccountName --sku Standard_LRS --encryption-services blob --location $Location --output json | ConvertFrom-Json
      if ($StorageAccount.ProvisioningState -eq "Succeeded") {
          Write-Host "`n Done" -NoNewline
          Write-Host " [Storage Account: $StorageAccountName]" -ForegroundColor Green
      } else {
          Write-Host "`n Error: Failed to create storage account" -ForegroundColor Red
          return $false
      }
  } catch {
      Write-Host "`n Error: Failed to create storage account" -ForegroundColor Red
      return $false
  }

  # return $true
}
function Get-AzureStorageAccountKey {
  param (
      [string]$ResourceGroupName,
      [string]$StorageAccountName
  )

  Write-Host "Retrieving storage account key..." -NoNewline

  try {
      $StorageAccountKey = az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" --output tsv
      Write-Host "`n Done" -NoNewline
      Write-Host " [Storage Account Key retrieved]" -ForegroundColor Green
      return $StorageAccountKey
  } catch {
      Write-Host "`n Error: Failed to retrieve storage account key" -ForegroundColor Red
      return $null
  }
}

function New-AzureStorageContainer {
  param (
      [string]$ContainerName,
      [string]$StorageAccountName,
      [string]$StorageAccountKey
  )

  Write-Host "Creating storage container... $ContainerName" -NoNewline

  try {
      $Container = az storage container create --name $ContainerName --account-name $StorageAccountName --account-key $StorageAccountKey --output json | ConvertFrom-Json
      if ($Container.created -eq $true) {
          Write-Host "`n Done" -NoNewline
          Write-Host " [Container: $ContainerName]" -ForegroundColor Green
      } else {
          Write-Host "`n Error: Failed to create storage container" -ForegroundColor Red
          return $false
      }
  } catch {
      Write-Host "`n Error: Failed to create storage container" -ForegroundColor Red
      return $false
  }

  # return $true
}

function New-AzureResourceGroup {
  param (
      [string]$ResourceGroupName,
      [string]$Location
  )

  Write-Host "Creating resource group... $ResourceGroupName" -NoNewline

  try {
      $ResourceGroup = az group create --name $ResourceGroupName --location $Location --output json | ConvertFrom-Json
      if ($ResourceGroup.Properties.ProvisioningState -eq "Succeeded") {
          Write-Host "`n Done" -NoNewline
          Write-Host " [Resource Group: $ResourceGroupName]" -ForegroundColor Green
      } else {
          Write-Host "`n Error: Failed to create resource group" -ForegroundColor Red
          return $false
      }
  } catch {
      Write-Host "`n Error: Failed to create resource group" -ForegroundColor Red
      return $false
  }

  # return $true
}

function Write-BackendTfFile {
    param (
        [string]$Path,
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$ContainerName,
        [string]$StorageAccountKey
    )

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

    Set-Content -Path $Path -Value $BackendTfContent
}
function Write-TfvarsToFile {
  param (
      [string]$Path,
      [hashtable]$Tfvars
  )

  $TfvarsContent = @()
  foreach ($Key in $Tfvars.Keys) {
      $Value = $Tfvars[$Key]
      $TfvarsContent += "$Key = `"$Value`""
  }

  Set-Content -Path $Path -Value ($TfvarsContent -join "`n")
}
function Get-TfvarsFromFile {
  param (
      [string]$Path
  )

  if (Test-Path -Path $Path) {
      $TfvarsContent = Get-Content -Path $Path

      $Tfvars = @{}
      foreach ($Line in $TfvarsContent) {
          if ($Line -match '^\s*(\S+)\s*=\s*"(.*)"\s*$') {
              $Key, $Value = $Matches[1], $Matches[2]
              $Tfvars[$Key] = $Value
          }
      }
      return $Tfvars
  } else {
      throw "File not found: $Path"
  }
}
function Get-AzureRegion {
  param (
      [array]$Regions
  )

  Write-Host "Available Azure Regions:"
  for ($i = 0; $i -lt $Regions.Count; $i++) {
      Write-Host "  $($i+1). $($Regions[$i])"
  }

  $SelectedRegion = $null
  while (-not $SelectedRegion) {
      $UserInput = Read-Host -Prompt "Type the number or name of the Azure Region you want to use"
      if ($UserInput -as [int] -gt 0 -and $UserInput -le $Regions.Count) {
          $SelectedRegion = $Regions[$UserInput - 1]
      } elseif ($Regions -contains $UserInput) {
          $SelectedRegion = $UserInput
      } else {
          Write-Host "Invalid selection. Please type the number or name of one of the available Azure Regions." -ForegroundColor Red
      }
  }

  return $SelectedRegion
}

# Main script
$BackendTfPath = "backend.tf"
$ProdSensitiveTfvarsPath = "backend.sensitive.tfvars"

if (Test-Path -Path $ProdSensitiveTfvarsPath) {
    $Tfvars = Get-TfvarsFromFile -Path $ProdSensitiveTfvarsPath
} else {
    $ResourceGroupName = Read-ResourceGroupNameFromUser
    $StorageAccountName = Read-StorageAccountNameFromUser
    $ContainerName = Read-ContainerNameFromUser

    $Tfvars = @{
        "backend_resource_group_name" = $ResourceGroupName
        "backend_storage_account_name" = $StorageAccountName
        "backend_container_name" = $ContainerName
    }

    Write-TfvarsToFile -Path $ProdSensitiveTfvarsPath -Tfvars $Tfvars
}

$ResourceGroupName = $Tfvars["backend_resource_group_name"]
$Location = Get-AzureRegion -Regions $Regions
$StorageAccountName = $Tfvars["backend_storage_account_name"]
$ContainerName = $Tfvars["backend_container_name"]

try {
    New-AzureResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location
    try {
        New-AzureStorageAccount -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -Location $Location
        try {
            $StorageAccountKey = Get-AzureStorageAccountKey -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName
            New-AzureStorageContainer -ContainerName $ContainerName -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
            Write-BackendTfFile -Path $BackendTfPath -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -ContainerName $ContainerName -StorageAccountKey $StorageAccountKey

            Write-Host "🚀 Successfully set up the Terraform backend:" -ForegroundColor Green
            Write-Host "  - Resource Group Name  : $ResourceGroupName" -ForegroundColor Yellow
            Write-Host "  - Storage Account Name : $StorageAccountName" -ForegroundColor Yellow
            Write-Host "  - Container Name       : $ContainerName" -ForegroundColor Yellow
            Write-Host "🎉 You're ready to use Terraform with your new backend!" -ForegroundColor Green
        } catch {
            Write-Host "Error: Failed to create storage container" -ForegroundColor Red
            Remove-StorageAccount -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName
            Remove-ResourceGroup -ResourceGroupName $ResourceGroupName
            exit 1
        }
    } catch {
        Write-Host "Error: Failed to create storage account" -ForegroundColor Red
        Remove-ResourceGroup -ResourceGroupName $ResourceGroupName
        exit 1
    }
} catch {
    Write-Host "Error: Failed to create resource group" -ForegroundColor Red
    exit 1
}