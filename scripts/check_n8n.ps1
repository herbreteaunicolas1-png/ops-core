param([string]$BaseUrl="http://localhost:5678")
curl.exe -sS "$BaseUrl/healthz"
