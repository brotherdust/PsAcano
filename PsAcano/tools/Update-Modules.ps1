$toolPath = $PSScriptRoot
$moduleRootPath = Split-Path -Path $toolPath -Parent


$moduleName = Split-Path -Path $moduleRootPath -Leaf
$author = 'Jarad Olson <brotherdust@gmail.com>'
$description = 'PowerShell module to interact with Acano (Cisco CMS) API'

#Create the module and related files
New-ModuleManifest -Path $moduleRootPath\$moduleName.psd1 `
                   -RootModule $moduleRootPath\$moduleName.psm1 `
                   -Description $description `
                   -PowerShellVersion 5.0 `
                   -Author $author

Test-ModuleManifest -Path $moduleRootPath\$moduleName.psd1
