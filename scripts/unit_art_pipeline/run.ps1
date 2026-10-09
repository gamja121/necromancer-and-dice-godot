param(
  [ValidateSet("build","preview","install","status")][string]$Action="preview",
  [string]$Config=(Join-Path $PSScriptRoot "profiles\hydra.json"),
  [string]$OutputRoot,
  [string]$PythonPath,
  [string]$GodotPath=$env:UNIT_ART_GODOT,
  [string]$UpscalerPath,
  [string]$ModelsPath,
  [string]$ApprovedBuildKey,
  [string]$ArchiveRoot,
  [int]$Gpu=0
)
$ErrorActionPreference="Stop"
$settingsPath=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "source_assets\unit_art_pipeline\local_tools.json"
$localTools=@{}
if(Test-Path -LiteralPath $settingsPath) {
  $loadedTools=Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
  foreach($property in $loadedTools.PSObject.Properties) {$localTools[$property.Name]=$property.Value}
}
foreach($entry in @(@("GodotPath","godot"),@("UpscalerPath","upscaler"),@("ModelsPath","models"))) {
  $value=Get-Variable -Name $entry[0] -ValueOnly
  if($value) {$localTools[$entry[1]]=$value}
  elseif($localTools[$entry[1]]) {Set-Variable -Name $entry[0] -Value $localTools[$entry[1]]}
}
if($localTools.Count) {
  New-Item -ItemType Directory -Path (Split-Path $settingsPath -Parent) -Force | Out-Null
  $localTools | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding utf8
}
if (-not $PythonPath) {
  $bundled=Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
  if(Test-Path -LiteralPath $bundled) {$PythonPath=$bundled}
  else {$PythonPath=(Get-Command python -ErrorAction Stop).Source}
}
$arguments=@((Join-Path $PSScriptRoot "unit_art_pipeline.py"),$Action,"--config",$Config,"--gpu",[string]$Gpu)
foreach($pair in @(@("--output",$OutputRoot),@("--godot",$GodotPath),@("--upscaler",$UpscalerPath),@("--models",$ModelsPath),@("--approved-key",$ApprovedBuildKey),@("--archive",$ArchiveRoot))) {
  if($pair[1]) {$arguments += $pair[0]; $arguments += $pair[1]}
}
& $PythonPath @arguments
if($LASTEXITCODE -ne 0) {throw "Unit-art pipeline stopped (exit $LASTEXITCODE)"}
