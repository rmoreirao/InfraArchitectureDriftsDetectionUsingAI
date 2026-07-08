<#
.SYNOPSIS
    Orchestrate an architecture drift review: run the deterministic Terraform steps
    (up to a plan JSON) using the current Azure credentials, then invoke the
    architecture-drift-review skill through the GitHub Copilot CLI.

.DESCRIPTION
    This script owns the *deterministic* half of the review:

      1. Validates inputs and required tooling (terraform, az, copilot).
      2. Enforces that Terraform runs against the CURRENT Azure credentials by
         calling `az account show`. If there is no active session the script
         aborts (run `az login` first). The current subscription id is injected
         into Terraform via TF_VAR_subscription_id / ARM_SUBSCRIPTION_ID.
      3. Runs terraform init -> validate -> plan -> show -json > plan.json.
         If any step fails the script aborts and does NOT invoke the skill.
      4. Invokes the architecture-drift-review skill via the Copilot CLI, passing
         the architecture design doc and the pre-generated plan.json. The skill
         performs the *non-deterministic* comparison and writes the report.

.PARAMETER ArchitectureDoc
    Path to the architecture design Markdown. Default: 'Solution_Design.md'.

.PARAMETER TerraformDir
    Path to the Terraform directory. Default: 'terraform'.

.PARAMETER Model
    Model passed to the Copilot CLI. Default: 'claude-opus-4.8'.

.PARAMETER OutputReport
    Path the skill should write the review report to. Default: 'architecture-review.md'.

.EXAMPLE
    ./run-architecture-review.ps1

.EXAMPLE
    ./run-architecture-review.ps1 -ArchitectureDoc docs/Design.md -TerraformDir infra
#>
[CmdletBinding()]
param(
    [string]$ArchitectureDoc = "Solution_Design.md",
    [string]$TerraformDir     = "terraform",
    [string]$Model            = "claude-opus-4.8",
    [string]$OutputReport     = "architecture-review.md"
)

$ErrorActionPreference = "Stop"

$SkillPath = ".github/skills/architecture-drift-review"

function Assert-Command {
    param([string]$Name, [string]$Hint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error "$Name is not installed or not on PATH. $Hint"
        exit 1
    }
}

# --- 1. Validate inputs & tooling ------------------------------------------------
if (-not (Test-Path -LiteralPath $ArchitectureDoc)) {
    Write-Error "Architecture design document not found: $ArchitectureDoc"
    exit 1
}
if (-not (Test-Path -LiteralPath $TerraformDir -PathType Container)) {
    Write-Error "Terraform directory not found: $TerraformDir"
    exit 1
}

Assert-Command -Name "terraform" -Hint "Install Terraform and re-run."
Assert-Command -Name "az"        -Hint "Install the Azure CLI and re-run."
Assert-Command -Name "copilot"   -Hint "Install the GitHub Copilot CLI and re-run."

# --- 2. Enforce current Azure credentials ---------------------------------------
Write-Host "==> Verifying Azure credentials (az account show)" -ForegroundColor Cyan
$accountJson = az account show -o json 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountJson)) {
    Write-Error "No active Azure session. Run 'az login' (and 'az account set --subscription <id>') before running this script."
    exit 1
}

$account = $accountJson | ConvertFrom-Json
$subscriptionId = $account.id
if ([string]::IsNullOrWhiteSpace($subscriptionId)) {
    Write-Error "Could not determine the current Azure subscription id from 'az account show'."
    exit 1
}

Write-Host "    Using subscription '$($account.name)' ($subscriptionId)" -ForegroundColor DarkGray
$env:TF_VAR_subscription_id = $subscriptionId
$env:ARM_SUBSCRIPTION_ID    = $subscriptionId

# --- 3. Terraform: init -> validate -> plan -> show -json ------------------------
$planJsonRelative = "plan.json"

Push-Location $TerraformDir
try {
    Write-Host "==> terraform init" -ForegroundColor Cyan
    terraform init -input=false -no-color
    if ($LASTEXITCODE -ne 0) { Write-Error "terraform init failed."; exit 1 }

    Write-Host "==> terraform validate" -ForegroundColor Cyan
    terraform validate -no-color
    if ($LASTEXITCODE -ne 0) { Write-Error "terraform validate failed."; exit 1 }

    Write-Host "==> terraform plan" -ForegroundColor Cyan
    terraform plan -input=false -no-color -out tfplan.binary
    if ($LASTEXITCODE -ne 0) {
        Write-Error "terraform plan failed. Aborting without invoking the skill (check Azure permissions / backend)."
        exit 1
    }

    Write-Host "==> terraform show -json" -ForegroundColor Cyan
    terraform show -json tfplan.binary | Out-File -FilePath $planJsonRelative -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Error "terraform show failed."; exit 1 }
}
finally {
    Pop-Location
}

$PlanJson = Join-Path $TerraformDir $planJsonRelative
if (-not (Test-Path -LiteralPath $PlanJson)) {
    Write-Error "Expected plan JSON was not produced: $PlanJson"
    exit 1
}
$PlanJsonFull = (Resolve-Path -LiteralPath $PlanJson).Path
Write-Host "    Wrote plan JSON to $PlanJsonFull" -ForegroundColor Green

# --- 4. Invoke the skill via the Copilot CLI ------------------------------------
$prompt = @"
Execute the skill at $SkillPath.
Use the architecture design document '$ArchitectureDoc' and the pre-generated Terraform
plan JSON '$PlanJsonFull' (already produced with the current Azure credentials).
Do not run Terraform yourself; the plan JSON is the source of truth for the reality model.
Write the compliance review report to '$OutputReport'.
"@

Write-Host "==> Invoking architecture-drift-review skill via Copilot ($Model)" -ForegroundColor Cyan
copilot -p $prompt --allow-all --autopilot --model $Model
$copilotExit = $LASTEXITCODE

if ($copilotExit -ne 0) {
    Write-Error "Copilot CLI exited with code $copilotExit."
    exit $copilotExit
}

Write-Host "Architecture drift review complete. Report: $OutputReport" -ForegroundColor Green
