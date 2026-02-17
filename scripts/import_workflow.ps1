param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [string]$BaseUrl = "http://localhost:5678",
  [string]$WorkflowFile = ".\workflows\imports\workflow_import_test_http.json"
)

if (-not (Test-Path $WorkflowFile)) {
  Write-Error "Fichier introuvable: $WorkflowFile"
  exit 1
}

# IMPORTANT: en PowerShell, utiliser curl.exe (pas l’alias curl)
$cmd = @(
  "curl.exe",
  "-sS",
  "-X", "POST", "$BaseUrl/rest/workflows",
  "-H", "X-N8N-API-KEY: $ApiKey",
  "-H", "Content-Type: application/json",
  "--data-binary", "@$WorkflowFile"
)

Write-Host "Import workflow -> $BaseUrl/rest/workflows"
& $cmd
