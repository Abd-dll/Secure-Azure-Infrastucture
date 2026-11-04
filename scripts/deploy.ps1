
# Configure PSReadLine autocompletion
Write-Host "`n[*] Configuring tab completion and predictions..." -ForegroundColor Yellow
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# Enable native tab completion for Azure CLI (az)
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $completionFile = New-TemporaryFile

    try {
        $env:ARGCOMPLETE_USE_TEMPFILES = 1
        $env:_ARGCOMPLETE_STDOUT_FILENAME = $completionFile.FullName
        $env:COMP_LINE = $commandAst.ToString()
        $env:COMP_POINT = $cursorPosition
        $env:_ARGCOMPLETE = 1
        $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
        $env:_ARGCOMPLETE_IFS = "`n"
        $env:_ARGCOMPLETE_SHELL = 'powershell'

        az 2>&1 | Out-Null

        Get-Content $completionFile.FullName | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_, $_, "ParameterValue", $_
            )
        }
    }
    finally {
        Remove-Item $completionFile.FullName -ErrorAction SilentlyContinue
        Remove-Item Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL -ErrorAction SilentlyContinue
    }
}

# Enable Azure Predictor if installed
if (Get-Module -ListAvailable -Name Az.Tools.Predictor) {
    Enable-AzPredictor
}

# Preload required Azure PowerShell modules
Write-Host "[*] Loading Azure PowerShell modules..." -ForegroundColor Yellow
$modules = @("Az.Accounts", "Az.Resources")

foreach ($mod in $modules) {
    if (Get-Module -ListAvailable -Name $mod) {
        Import-Module $mod -ErrorAction SilentlyContinue
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  2. Azure Connection (ARM)                               " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Connect to Azure Resource Manager (ARM / Az)
Write-Host "`n[ARM] Connecting to Azure (Connect-AzAccount)..." -ForegroundColor Yellow
Connect-AzAccount -ErrorAction Stop

# Check whether the resource group already exists
$location = "example"
$rgName = "example"

if ($null -eq (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue)) {

    # Define resource tags
    $tags = @{
        Project     = "example"
        Environment = "example"
        Owner       = "example"
        ManagedBy   = "example"
    }

    # Create the resource group
    New-AzResourceGroup `
        -Name $rgName `
        -Location $location `
        -Tag $tags `
        -ErrorAction Stop
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Resource Group Ready" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Generating SSH Key..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Generate SSH key pair
$sshKeyPath = "<path_to_ssh_key>"

ssh-keygen -t ed25519 -f $sshKeyPath

if ($LASTEXITCODE -ne 0) {
    throw "SSH key generation failed (exit code: $LASTEXITCODE)."
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "SSH Key Generated Successfully" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Deploying Azure Resources..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Resource deployment (optional What-If preview)
# New-AzResourceGroupDeployment -Name "1stDeploymentProjectTest" -ResourceGroupName $rgName -TemplateFile <"file_path"> -sshKey (Get-Content "$sshKeyPath.pub" -Raw).Trim() -vmSize 'Standard_D2s_v4' -storageName "example" -kvName "example" -WhatIf

try {
    $deployment = New-AzResourceGroupDeployment `
        -Name "1stDeploymentProjectTest" `
        -ResourceGroupName $rgName `
        -TemplateFile <"file_path"> `
        -sshKey (Get-Content "$sshKeyPath.pub" -Raw -ErrorAction Stop).Trim() `
        -vmSize 'Standard_D2s_v4' `
        -storageName "example" `
        -kvName "example" `
        -ErrorAction Stop

    if ($deployment.ProvisioningState -ne "Succeeded") {
        throw "Deployment did not succeed. State: $($deployment.ProvisioningState)"
    }

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "Azure Resources Deployed Successfully" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
catch {
    Write-Host "`n==========================================================" -ForegroundColor Red
    Write-Host "Azure Resource Deployment Failed" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red

    throw
}
