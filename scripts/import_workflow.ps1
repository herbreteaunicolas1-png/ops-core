param(
  [Parameter(Mandatory=$true)]
  [string]$File
)

$Base = $env:N8N_BASE
$ApiKey = $env:N8N_API_KEY

if ([string]::IsNullOrWhiteSpace($Base)) { throw "ENV N8N_BASE manquant. Ex: `$env:N8N_BASE='http://localhost:5678'" }
if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw "ENV N8N_API_KEY manquant. Ex: `$env:N8N_API_KEY='xxxx'" }
if (!(Test-Path $File)) { throw "Fichier introuvable: $File" }

$headers = @{
  "X-N8N-API-KEY" = $ApiKey
  "Content-Type" = "application/json"
}

# lecture raw + import
$body = Get-Content -Raw -Path $File
Invoke-RestMethod -Method Post -Uri "$Base/api/v1/workflows" -Headers $headers -Body $body
