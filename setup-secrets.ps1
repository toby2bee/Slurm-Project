# PowerShell script to set up Docker secrets for the Slurm project
# This script helps create secret files securely on Windows

$SecretsDir = ".\secrets"

# Create secrets directory if it doesn't exist
if (-not (Test-Path $SecretsDir)) {
    New-Item -ItemType Directory -Path $SecretsDir | Out-Null
}

Write-Host "Setting up Docker secrets for Slurm project..."
Write-Host "=============================================="
Write-Host ""

# Function to create a secret file
function Create-Secret {
    param(
        [string]$SecretName,
        [string]$Prompt
    )
    
    $FilePath = Join-Path $SecretsDir "$SecretName.txt"
    
    if (Test-Path $FilePath) {
        $Overwrite = Read-Host "$Prompt file already exists. Overwrite? (y/N)"
        if ($Overwrite -ne "y" -and $Overwrite -ne "Y") {
            Write-Host "Skipping $SecretName..."
            return
        }
    }
    
    $SecurePassword = Read-Host -Prompt $Prompt -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    [System.IO.File]::WriteAllText($FilePath, $PlainPassword)
    $PlainPassword = $null
    
    # Set file permissions (Windows)
    $acl = Get-Acl $FilePath
    $acl.SetAccessRuleProtection($true, $false)
    $permission = $env:USERNAME, "FullControl", "Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $FilePath $acl
    
    Write-Host "✓ Created $FilePath"
}

# Function to generate random password
function Generate-RandomSecret {
    param([string]$SecretName)
    
    $FilePath = Join-Path $SecretsDir "$SecretName.txt"
    
    if (Test-Path $FilePath) {
        $Overwrite = Read-Host "$SecretName file already exists. Overwrite? (y/N)"
        if ($Overwrite -ne "y" -and $Overwrite -ne "Y") {
            Write-Host "Skipping $SecretName..."
            return
        }
    }
    
    # Generate 32-character random password
    $Bytes = New-Object byte[] 32
    $RNG = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $RNG.GetBytes($Bytes)
    $Password = [Convert]::ToBase64String($Bytes)
    
    [System.IO.File]::WriteAllText($FilePath, $Password)
    
    # Set file permissions
    $acl = Get-Acl $FilePath
    $acl.SetAccessRuleProtection($true, $false)
    $permission = $env:USERNAME, "FullControl", "Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $FilePath $acl
    
    Write-Host "✓ Generated random password for $SecretName"
}

# Ask user preference
Write-Host "How would you like to set passwords?"
Write-Host "1) Enter passwords interactively (most secure)"
Write-Host "2) Generate random passwords automatically"
$Choice = Read-Host "Enter choice (1 or 2)"

switch ($Choice) {
    "1" {
        Write-Host ""
        Write-Host "Enter passwords (they will not be displayed):"
        Create-Secret "mysql_root_password" "MySQL root password"
        Create-Secret "mysql_password" "MySQL slurm user password"
        Create-Secret "root_password" "Root user SSH password"
        Create-Secret "wunmi_password" "Wunmi user SSH password"
    }
    "2" {
        Write-Host ""
        Write-Host "Generating random passwords..."
        Generate-RandomSecret "mysql_root_password"
        Generate-RandomSecret "mysql_password"
        Generate-RandomSecret "root_password"
        Generate-RandomSecret "wunmi_password"
        Write-Host ""
        Write-Host "Random passwords generated! To view them, use:"
        Write-Host "  Get-Content secrets\mysql_root_password.txt"
        Write-Host "  Get-Content secrets\mysql_password.txt"
        Write-Host "  Get-Content secrets\root_password.txt"
        Write-Host "  Get-Content secrets\wunmi_password.txt"
    }
    default {
        Write-Host "Invalid choice. Exiting."
        exit 1
    }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "✓ All secrets created successfully!"
Write-Host ""
Write-Host "Secret files created in: $SecretsDir"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Review the secrets if needed"
Write-Host "2. Deploy with: docker-compose up -d"
Write-Host ""

