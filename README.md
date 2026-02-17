# ops-core

Core d’exécution (POC local) + packs métiers (V1 = cash-collector).

## Stack validée (mode POC gratuit)
- Docker Desktop (WSL2)
- n8n (local)
- PowerShell + VS Code
- Git/GitHub
- (Plus tard: OVH SMTP + VPS + HTTPS)

## Dossiers
- workflows/imports : JSON prêts à importer dans n8n (API)
- workflows/exports : exports depuis n8n (à ignorer au début)
- packs/cash-collector : assets pack (templates/tests)
- scripts : scripts PowerShell utilitaires

## Next
1) Créer API key n8n
2) Importer workflow JSON via script scripts/import_workflow.ps1
