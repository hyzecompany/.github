# Mostra, para cada repositório da Hyze, alterações pendentes, commits ainda não enviados e os
# últimos commits. Rode no início de cada tarefa:  .\status.ps1
$repos = Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }
foreach ($r in $repos) {
  Write-Host "`n=== $($r.Name) ===" -ForegroundColor Cyan
  Push-Location $r.FullName
  $dirty = git status --short
  if ($dirty) { Write-Host "Alterações não commitadas:" -ForegroundColor Yellow; $dirty }
  $ahead = git log --oneline "@{u}..HEAD" 2>$null
  if ($ahead) { Write-Host "Commits ainda sem push:" -ForegroundColor Yellow; $ahead }
  git log --oneline -3 --format="%h %ad %s" --date=format:"%d/%m %H:%M"
  Pop-Location
}
