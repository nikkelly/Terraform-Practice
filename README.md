# Terraform Project for Resource Group Creation

This Terraform project creates an Azure Resource Group using a simple and modular structure. It is designed to be used with Windows, PowerShell, and Visual Studio Code.

## Prerequisites

1. Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest) on your machine.
2. Install [Terraform](https://www.terraform.io/downloads.html) on your machine.
3. Install [Visual Studio Code](https://code.visualstudio.com/download) on your machine.
4. Install the [Terraform extension](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform) for Visual Studio Code.

## Project Structure

- `modules/`: Contains reusable Terraform modules.

## Setup

Setup
1. Clone the repository to your local machine.
2. Open the project in Visual Studio Code or your preferred editor.
3. In the terminal, navigate to the project root directory.
4. Run the `setup_backend.ps1` script to set up the Terraform backend in Azure. This script will prompt you to input required information for your backend configuration. If the backend.sensitive.tfvars file does not exist, it will be created with the provided information:
5. The setup_backend.ps1 script will generate a backend.tf file with the necessary configurations for the Terraform backend.

6. Review and modify the variable values in prod.tfvars and backend.sensitive.tfvars files as needed. Make sure these files contain the correct values for your environment and resources. Keep sensitive information like secrets and API keys in the backend.sensitive.tfvars file, and use prod.tfvars for other variables.

## Usage

### Workspaces

- To create a new workspace for your environment, run:
`terraform workspace new <workspace_name>`

Replace `<workspace_name>` with a name for your environment, such as "dev", "staging", or "prod".

- To switch between workspaces, run:
`terraform workspace select <workspace_name>`

Replace `<workspace_name>` with the name of the workspace you want to switch to.

### Resource Group Management

1. Initialize the Terraform working directory:

`terraform init`

2. (Optional) Format your Terraform files to ensure they follow the standard formatting conventions:

`terraform fmt`

3. (Optional) Validate the Terraform configuration files for any errors:

`terraform validate`

4. (Optional) Generate an execution plan to preview the changes that will be made to your infrastructure:

`terraform plan -var-file="prod.tfvars"`

5. To create a resource group, update the values in `prod.tfvars` and `backend.sensitive.tfvars`, then run:

`terraform apply -var-file="prod.tfvars"`

6. To destroy a resource group, run:

`terraform destroy -var-file="prod.tfvars"`


## Contributing

To create or modify Terraform modules, update the files in the `modules/` directory.

Please make sure to test your changes in an isolated environment before pushing them to the repository.
