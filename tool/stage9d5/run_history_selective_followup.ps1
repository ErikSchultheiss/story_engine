param(
  [int]$Rounds = 3,
  [int]$Samples = 7,
  [int]$Warmups = 2
)

$ErrorActionPreference = 'Stop'
if ($Rounds -lt 1) { throw 'Rounds must be at least 1.' }
if ($Samples -lt 1) { throw 'Samples must be at least 1.' }
if ($Warmups -lt 0) { throw 'Warmups must be non-negative.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path 'build/stage9d5_selective' "run-$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$metadata = [ordered]@{
  startedAt = (Get-Date).ToString('o')
  dartVersion = (& dart --version 2>&1 | Out-String).Trim()
  rounds = $Rounds
  samples = $Samples
  warmups = $Warmups
  variants = @('B','D','E')
  runtimeSourceSha256 = (Get-FileHash 'lib/src/orchestration/story_narrative_runtime.dart' -Algorithm SHA256).Hash.ToLowerInvariant()
  engineSourceSha256 = (Get-FileHash 'lib/src/runtime/story_engine.dart' -Algorithm SHA256).Hash.ToLowerInvariant()
  benchmarkSourceSha256 = (Get-FileHash 'benchmark/stage9d5_history_ab_isolation.dart' -Algorithm SHA256).Hash.ToLowerInvariant()
}
try {
  $metadata['gitRevision'] = (& git rev-parse HEAD 2>$null | Out-String).Trim()
} catch {
  $metadata['gitRevision'] = $null
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $outDir 'metadata.json')

# Rotate B (eager+indexed), D (lazy+indexed), and E (lazy checkpoint with
# selective pre-propagation materialization) so each occupies every order slot.
$orders = @(
  @('B','E','D'),
  @('D','B','E'),
  @('E','D','B')
)

for ($round = 0; $round -lt $Rounds; $round++) {
  $order = @($orders[$round % $orders.Count])
  $roundNumber = $round + 1
  foreach ($variant in $order) {
    $target = Join-Path $outDir ("round-{0:D2}-variant-{1}.json" -f $roundNumber, $variant)
    Write-Host "Round $roundNumber / variant $variant -> $target"
    & dart run benchmark/stage9d5_history_ab_isolation.dart `
      "--variant=$variant" `
      "--samples=$Samples" `
      "--warmups=$Warmups" `
      --json | Set-Content -Encoding utf8 $target
    if ($LASTEXITCODE -ne 0) {
      throw "Variant $variant failed with exit code $LASTEXITCODE."
    }
  }
}

Write-Host "Stage 9D5 selective follow-up evidence written to $outDir"
