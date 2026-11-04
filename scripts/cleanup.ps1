
$location = "example"
$rgName = "example"

try {
    $ErrorActionPreference = "Stop"

    $VaultName = (Get-AzKeyVault -ResourceGroupName $rgName).Name

    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host "Deleting Key Vault..." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    Remove-AzKeyVault -ResourceGroupName $rgName -VaultName $VaultName

    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host "Purging Soft-Deleted Key Vault..." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    Remove-AzKeyVault -VaultName $VaultName -InRemovedState -Location $location

    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host "Deleting Resource Groups..." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    Remove-AzResourceGroup -Name $rgName
    Remove-AzResourceGroup -Name NetworkWatcherRG

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "Azure Resources Deleted Successfully" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
catch {
    Write-Host "`n==========================================================" -ForegroundColor Red
    Write-Host "Azure Resource Cleanup Failed" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red

    throw
}
finally {
    $ErrorActionPreference = "Continue"
}

