<#
  Cria os repositórios da Hyze na organização do GitHub e faz o primeiro push, na ordem certa.

  Pré-requisitos (uma vez):
    winget install GitHub.cli
    gh auth login          # escolha GitHub.com > HTTPS > login pelo navegador
    npm i -g pnpm@10       # se ainda não tiver o pnpm

  Uso (no terminal do VS Code, dentro da pasta "hyze"):
    powershell -ExecutionPolicy Bypass -File .\publicar-github.ps1
    # repositórios privados (atenção: no plano grátis, segredos da organização não chegam a repos privados):
    powershell -ExecutionPolicy Bypass -File .\publicar-github.ps1 -Visibility private

  Pode rodar de novo sem problema: o que já existe é pulado.
#>
param(
  [string]$Org = "hyzecompany",
  [ValidateSet("public", "private")][string]$Visibility = "public"
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Run([string]$cmd) {
  Write-Host "  > $cmd" -ForegroundColor DarkGray
  Invoke-Expression $cmd
  if ($LASTEXITCODE -ne 0) { throw "Falhou: $cmd" }
}

function Publish([string]$Name, [string]$Description) {
  Write-Host "`n=== $Org/$Name ===" -ForegroundColor Cyan
  Push-Location (Join-Path $Root $Name)
  try {
    gh repo view "$Org/$Name" *> $null
    if ($LASTEXITCODE -ne 0) {
      Run "gh repo create $Org/$Name --$Visibility --description `"$Description`""
    } else {
      Write-Host "  repositório já existe" -ForegroundColor DarkYellow
    }
    git remote get-url origin *> $null
    if ($LASTEXITCODE -ne 0) { Run "git remote add origin https://github.com/$Org/$Name.git" }
    Run "git push -u origin main"
  } finally { Pop-Location }
}

gh auth status
if ($LASTEXITCODE -ne 0) { throw "Faça login primeiro: gh auth login" }

# 1) Perfil da organização + workflows reutilizáveis (os outros repos dependem deles)
Publish ".github" "Perfil da organização e workflows compartilhados"

# 2) Design system + tag de versão (os sites instalam por tag)
Publish "hyze-ui" "Design system Hyze: tokens, componentes, layout e animações"
Push-Location (Join-Path $Root "hyze-ui")
try {
  $version = (Get-Content package.json -Raw | ConvertFrom-Json).version
  git rev-parse "v$version" *> $null
  if ($LASTEXITCODE -ne 0) { Run "git tag v$version" }
  Run "git push origin v$version"
} finally { Pop-Location }

# 3) Sites: gera o lockfile já apontando para o hyze-ui publicado, commita e publica
$sites = @{
  "hyze-hub"         = "Site do grupo Hyze (hyzecompany.com.br)"
  "hyze-sites"       = "Hyze Sites — criação de sites (sites.hyzecompany.com.br)"
  "hyze-consultoria" = "Hyze Consultoria — consultoria em TI (consultoria.hyzecompany.com.br)"
}
foreach ($name in @("hyze-hub", "hyze-sites", "hyze-consultoria")) {
  Push-Location (Join-Path $Root $name)
  try {
    Write-Host "`n--- instalando dependências de $name ---" -ForegroundColor Cyan
    Run "pnpm install"
    git add pnpm-lock.yaml
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
      Run "git commit -m `"chore: lockfile com @hyze/ui publicado`" -m `"Agente: vscode`""
    }
  } finally { Pop-Location }
  Publish $name $sites[$name]
}

# 4) API de leads
Publish "hyze-leads-api" "API de leads dos sites Hyze (Hono + D1 + Turnstile)"

Write-Host "`nPronto! Veja em https://github.com/$Org" -ForegroundColor Green
Write-Host "Próximo passo: em github.com/organizations/$Org/settings/secrets/actions crie os segredos"
Write-Host "CLOUDFLARE_API_TOKEN e CLOUDFLARE_ACCOUNT_ID, e a variável PUBLIC_TURNSTILE_SITE_KEY."
