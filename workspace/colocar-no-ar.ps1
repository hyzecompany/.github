<#
  Coloca a Hyze no ar na Cloudflare (plano gratuito): API de leads + banco D1 + os sites.

  Antes de rodar (uma vez, no painel da Cloudflare — dash.cloudflare.com):
    1. Domínio: "Add a domain" > hyzecompany.com.br > plano Free. No Registro.br, troque os
       DNS pelos 2 nameservers que a Cloudflare mostrar e espere ficar "Active".
    2. Turnstile: "Turnstile" > "Add widget" > domínio hyzecompany.com.br, modo "Managed".
       Guarde a Site Key (pública) e a Secret Key.
    3. Dependências instaladas: tarefa "Hyze: instalar dependências" no VS Code.

  Uso (no terminal do VS Code, dentro da pasta "hyzecompany"):
    powershell -ExecutionPolicy Bypass -File .\colocar-no-ar.ps1
  O script pede o que faltar (login na Cloudflare pelo navegador, chaves do Turnstile).
  Pode rodar de novo a qualquer momento: ele reaproveita o que já existe e só republica.
#>
param(
  [string]$TurnstileSiteKey = "",
  [string]$AnalyticsToken = "",
  [string]$DatabaseName = "hyze-leads"
)

$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot

function Run([string]$cmd) {
  Write-Host "  > $cmd" -ForegroundColor DarkGray
  Invoke-Expression $cmd
  if ($LASTEXITCODE -ne 0) { throw "Falhou: $cmd" }
}
function Step([string]$text) { Write-Host "`n=== $text ===" -ForegroundColor Cyan }

# ---------- API de leads ----------
Push-Location (Join-Path $Root "hyze-leads-api")
try {
  Step "Login na Cloudflare"
  pnpm exec wrangler whoami 2>&1 | Out-String | Tee-Object -Variable who | Out-Null
  if ($who -match "not authenticated|You are not logged in") { Run "pnpm exec wrangler login" }
  else { Write-Host "  já autenticado" -ForegroundColor DarkGray }

  Step "Banco D1 ($DatabaseName)"
  $dbs = (pnpm exec wrangler d1 list --json | Out-String) | ConvertFrom-Json
  $db = $dbs | Where-Object { $_.name -eq $DatabaseName } | Select-Object -First 1
  if (-not $db) {
    Run "pnpm exec wrangler d1 create $DatabaseName"
    $dbs = (pnpm exec wrangler d1 list --json | Out-String) | ConvertFrom-Json
    $db = $dbs | Where-Object { $_.name -eq $DatabaseName } | Select-Object -First 1
  }
  if (-not $db) { throw "Não encontrei o banco $DatabaseName depois de criar." }
  Write-Host "  database_id: $($db.uuid)"

  $cfg = Get-Content wrangler.jsonc -Raw
  $newCfg = $cfg -replace '"database_id":\s*"[^"]*"', ('"database_id": "' + $db.uuid + '"')
  if ($newCfg -ne $cfg) {
    [System.IO.File]::WriteAllText((Join-Path $PWD "wrangler.jsonc"), $newCfg)
    git add wrangler.jsonc
    git commit -m "chore: database_id do D1 de produção" -m "Agente: vscode" | Out-Null
    Write-Host "  wrangler.jsonc atualizado e commitado (faça push depois)" -ForegroundColor DarkYellow
  }

  Step "Migrações do banco (produção)"
  Run "pnpm exec wrangler d1 migrations apply $DatabaseName --remote"

  Step "Publicando a API (api.hyzecompany.com.br)"
  Run "pnpm run deploy"

  Step "Segredo do Turnstile na API"
  $secrets = pnpm exec wrangler secret list 2>&1 | Out-String
  if ($secrets -notmatch "TURNSTILE_SECRET_KEY") {
    $secure = Read-Host "Cole a SECRET KEY do Turnstile" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
      [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    $plain | pnpm exec wrangler secret put TURNSTILE_SECRET_KEY
    if ($LASTEXITCODE -ne 0) { throw "Falhou ao gravar o segredo" }
    $plain = $null
  } else { Write-Host "  já configurado" -ForegroundColor DarkGray }
} finally { Pop-Location }

# ---------- Sites ----------
if (-not $TurnstileSiteKey) { $TurnstileSiteKey = Read-Host "Cole a SITE KEY do Turnstile (pública)" }
$env:PUBLIC_TURNSTILE_SITE_KEY = $TurnstileSiteKey
$env:PUBLIC_CF_ANALYTICS_TOKEN = $AnalyticsToken
Remove-Item Env:PUBLIC_API_URL -ErrorAction SilentlyContinue  # produção usa api.hyzecompany.com.br

$sites = [ordered]@{
  "hyze-hub"         = "https://hyzecompany.com.br"
  "hyze-sites"       = "https://sites.hyzecompany.com.br"
  "hyze-consultoria" = "https://consultoria.hyzecompany.com.br"
}
foreach ($name in $sites.Keys) {
  Step "Publicando $name"
  Push-Location (Join-Path $Root $name)
  try {
    Run "pnpm build"
    Run "pnpm run deploy"
  } finally { Pop-Location }
}

Write-Host "`nNo ar!" -ForegroundColor Green
foreach ($u in $sites.Values) { Write-Host "  $u" }
Write-Host "  https://api.hyzecompany.com.br/health"
Write-Host "`nO certificado HTTPS dos domínios pode levar alguns minutos na primeira vez."
