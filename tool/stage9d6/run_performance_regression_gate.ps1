param(
  [int]$Samples = 11,
  [int]$Warmups = 3,
  [string]$OutputRoot = "build/stage9d6"
)

$ErrorActionPreference = "Stop"

if ($Samples -le 0) {
  throw "Samples must be greater than zero."
}
if ($Warmups -lt 0) {
  throw "Warmups must be zero or greater."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDirectory = Join-Path $OutputRoot "run-$timestamp"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$outputPath = Join-Path $outputDirectory "stage9d6-performance-gate.json"

Write-Host "Running Story Engine Stage 9D6 performance regression gate..."
Write-Host "Samples: $Samples; warm-ups: $Warmups"
Write-Host "Output: $outputPath"

dart run benchmark/stage9d6_performance_regression_gate.dart `
  "--samples=$Samples" `
  "--warmups=$Warmups" `
  "--output=$outputPath"

if ($LASTEXITCODE -eq 2) {
  Write-Warning "Stage 9D6 performance evidence is INCONCLUSIVE; repeat the run. See $outputPath"
  exit 2
}
if ($LASTEXITCODE -ne 0) {
  $gateExitCode = $LASTEXITCODE
  Write-Error -ErrorAction Continue "Stage 9D6 performance regression gate failed. See $outputPath"
  exit $gateExitCode
}

Write-Host "Stage 9D6 performance regression gate passed."
Write-Host "Report: $outputPath"
