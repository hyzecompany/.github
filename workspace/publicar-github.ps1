<#
  Cria os repositórios da Hyze na organização do GitHub e faz o primeiro push, na ordem certa.

  Funciona de dois jeitos:
    - Só com o Git: crie antes os repositórios VAZIOS no site do GitHub (o script lista quais
      faltam e o link); o login acontece pelo navegador no primeiro push (Git Credential Manager).
    - Com o GitHub CLI (opcional: winget install GitHub.cli; gh auth login): o script cria os
      repositórios sozinho.
  Também precisa do pnpm (npm i -g pnpm@10).

  Uso (no terminal do VS Code, dentro da pasta "hyzecompany"):
    powershell -ExecutionPolicy Bypass -File .\publicar-github.ps1
    # repositórios privados (atenção: no plano grátis, segredos da organização não chegam a repos privados):
    powershell -ExecutionPolicy Bypass -File .\publicar-github.ps1 -Visibility private

  Pode rodar de novo sem problema: o que já existe é pulado.
#>
param(
  [string]$Org = "hyzecompany",
  [ValidateSet("public", "private")][string]$Visibility = "public"
)

# "Continue": no Windows PowerShell 5.1, mensagens normais do git no stderr não devem abortar;
# cada comando é conferido pelo código de saída ($LASTEXITCODE).
$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot

function Run([string]$cmd) {
  Write-Host "  > $cmd" -ForegroundColor DarkGray
  Invoke-Expression $cmd
  if ($LASTEXITCODE -ne 0) { throw "Falhou: $cmd" }
}

$HasGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
if ($HasGh) { gh auth status *> $null; if ($LASTEXITCODE -ne 0) { $HasGh = $false } }

$AllRepos = [ordered]@{
  ".github"          = "Perfil da organização e workflows compartilhados"
  "hyze-ui"          = "Design system Hyze: tokens, componentes, layout e animações"
  "hyze-hub"         = "Site do grupo Hyze (hyzecompany.com.br)"
  "hyze-sites"       = "Hyze Sites — criação de sites (sites.hyzecompany.com.br)"
  "hyze-consultoria" = "Hyze Consultoria — consultoria em TI (consultoria.hyzecompany.com.br)"
  "hyze-leads-api"   = "API de leads dos sites Hyze (Hono + D1 + Turnstile)"
}

function RepoExists([string]$Name) {
  # Só consulta; não abre janela de login (repos privados aparecem se o login já estiver salvo).
  $env:GIT_TERMINAL_PROMPT = "0"; $env:GCM_INTERACTIVE = "never"
  try {
    git ls-remote "https://github.com/$Org/$Name.git" *> $null
    return ($LASTEXITCODE -eq 0)
  } finally {
    Remove-Item Env:GIT_TERMINAL_PROMPT, Env:GCM_INTERACTIVE -ErrorAction SilentlyContinue
  }
}

if (-not $HasGh) {
  Write-Host "GitHub CLI não encontrado: usando só o Git." -ForegroundColor DarkYellow
  $missing = @($AllRepos.Keys | Where-Object { -not (RepoExists $_) })
  if ($missing.Count -gt 0) {
    Write-Host "`nCrie estes repositórios VAZIOS (sem README, sem .gitignore, sem licença)" -ForegroundColor Yellow
    Write-Host "em https://github.com/organizations/$Org/repositories/new  — visibilidade: $Visibility`n"
    foreach ($m in $missing) { Write-Host ("  - {0,-18} {1}" -f $m, $AllRepos[$m]) }
    Write-Host "`nDepois rode este script de novo."
    exit 1
  }
}

function Publish([string]$Name, [string]$Description) {
  Write-Host "`n=== $Org/$Name ===" -ForegroundColor Cyan
  Push-Location (Join-Path $Root $Name)
  try {
    if ($HasGh -and -not (RepoExists $Name)) {
      Run "gh repo create $Org/$Name --$Visibility --description `"$Description`""
    }
    git remote get-url origin *> $null
    if ($LASTEXITCODE -ne 0) { Run "git remote add origin https://github.com/$Org/$Name.git" }
    Run "git push -u origin main"
  } finally { Pop-Location }
}

# 1) Perfil da organização + workflows reutilizáveis (os outros repos dependem deles)
Publish ".github" $AllRepos[".github"]

# 2) Design system + tag de versão (os sites instalam por tag)
Publish "hyze-ui" $AllRepos["hyze-ui"]
Push-Location (Join-Path $Root "hyze-ui")
try {
  $version = (Get-Content package.json -Raw | ConvertFrom-Json).version
  git rev-parse "v$version" *> $null
  if ($LASTEXITCODE -ne 0) { Run "git tag v$version" }
  Run "git push origin v$version"
} finally { Pop-Location }

# 3) Sites: gera o lockfile já apontando para o hyze-ui publicado, commita e publica
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
  Publish $name $AllRepos[$name]
}

# 4) API de leads
Publish "hyze-leads-api" $AllRepos["hyze-leads-api"]

Write-Host "`nPronto! Veja em https://github.com/$Org" -ForegroundColor Green
Write-Host "Próximo passo: em github.com/organizations/$Org/settings/secrets/actions crie os segredos"
Write-Host "CLOUDFLARE_API_TOKEN e CLOUDFLARE_ACCOUNT_ID, e a variável PUBLIC_TURNSTILE_SITE_KEY."
