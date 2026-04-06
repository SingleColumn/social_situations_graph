# Run from project root:
# .\graph_design\pipeline\run_graph_pipeline.ps1 -InputMarkdown ".\graph_design\spec\graph_specification.md" -Neo4jPassword "YOUR_PASSWORD"

param(
    [string]$InputMarkdown = "",
    [string]$OutputDir = "",
    [string]$PythonCommand = "",
    [string]$CypherShellPath = "",
    [string]$Neo4jUri = "",
    [string]$Neo4jUser = "",
    [string]$Neo4jPassword = "",
    [string]$Neo4jDatabase = ""
)

$ErrorActionPreference = "Stop"

function Resolve-PathSafe {
    param([string]$PathValue)
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PathValue))
}

function Resolve-InputMarkdownPath {
    param([string]$PathValue)

    $candidate = Resolve-PathSafe $PathValue
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    # Backward compatibility for the older ".\graph\..." layout.
    if ($PathValue -match '(^|[\\/])graph([\\/].*)$') {
        $remappedPath = $PathValue -replace '(^|[\\/])graph([\\/])', '$1graph_design$2'
        $remappedCandidate = Resolve-PathSafe $remappedPath
        if (Test-Path -LiteralPath $remappedCandidate) {
            Write-Host "Input markdown path not found; using migrated path: $remappedCandidate"
            return $remappedCandidate
        }
    }

    return $candidate
}

function Resolve-ProjectPath {
    param([string]$PathValue)
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $PathValue))
}

function Resolve-CommandExecutable {
    param([string]$CommandValue)
    if ([string]::IsNullOrWhiteSpace($CommandValue)) {
        return $null
    }

    if (Test-Path -LiteralPath $CommandValue) {
        return (Resolve-Path -LiteralPath $CommandValue).Path
    }

    $cmd = Get-Command -Name $CommandValue -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Read-DotEnv {
    param([string]$DotEnvPath)
    $values = @{}
    if (-not (Test-Path -LiteralPath $DotEnvPath)) {
        return $values
    }

    Get-Content -LiteralPath $DotEnvPath | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) {
            return
        }
        $parts = $line.Split("=", 2)
        $key = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")
        if ($key) {
            $values[$key] = $value
        }
    }
    return $values
}

$envFilePath = Resolve-ProjectPath "..\..\.env"
$dotenv = Read-DotEnv $envFilePath

# Parameter value > environment variable > .env value > hardcoded default
if ([string]::IsNullOrWhiteSpace($InputMarkdown)) {
    $InputMarkdown = if ($env:INPUT_MARKDOWN) { $env:INPUT_MARKDOWN } elseif ($dotenv.ContainsKey("INPUT_MARKDOWN")) { $dotenv["INPUT_MARKDOWN"] } else { ".\graph_design\spec\graph_specification.md" }
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = if ($env:OUTPUT_DIR) { $env:OUTPUT_DIR } elseif ($dotenv.ContainsKey("OUTPUT_DIR")) { $dotenv["OUTPUT_DIR"] } else { ".\graph_design\cypher" }
}
if ([string]::IsNullOrWhiteSpace($PythonCommand)) {
    $PythonCommand = if ($env:PYTHON_COMMAND) { $env:PYTHON_COMMAND } elseif ($dotenv.ContainsKey("PYTHON_COMMAND")) { $dotenv["PYTHON_COMMAND"] } else {
        # Auto-detect: prefer the project .venv over the system python.
        # Check relative to CWD (expected: project root) and relative to PSScriptRoot.
        $venvFromCwd = Join-Path (Get-Location) ".venv\Scripts\python.exe"
        $venvFromScript = Resolve-ProjectPath "..\..\.venv\Scripts\python.exe"
        if (Test-Path -LiteralPath $venvFromCwd) { $venvFromCwd }
        elseif (Test-Path -LiteralPath $venvFromScript) { $venvFromScript }
        else { "python" }
    }
}
if ([string]::IsNullOrWhiteSpace($CypherShellPath)) {
    $CypherShellPath = if ($env:CYPHER_SHELL_PATH) { $env:CYPHER_SHELL_PATH } elseif ($dotenv.ContainsKey("CYPHER_SHELL_PATH")) { $dotenv["CYPHER_SHELL_PATH"] } else { "cypher-shell" }
}
if ([string]::IsNullOrWhiteSpace($Neo4jUri)) {
    $Neo4jUri = if ($env:NEO4J_URI) { $env:NEO4J_URI } elseif ($dotenv.ContainsKey("NEO4J_URI")) { $dotenv["NEO4J_URI"] } else { "neo4j://localhost:7687" }
}
if ([string]::IsNullOrWhiteSpace($Neo4jUser)) {
    $Neo4jUser = if ($env:NEO4J_USER) { $env:NEO4J_USER } elseif ($dotenv.ContainsKey("NEO4J_USER")) { $dotenv["NEO4J_USER"] } else { "neo4j" }
}
if ([string]::IsNullOrWhiteSpace($Neo4jPassword)) {
    $Neo4jPassword = if ($env:NEO4J_PASSWORD) { $env:NEO4J_PASSWORD } elseif ($dotenv.ContainsKey("NEO4J_PASSWORD")) { $dotenv["NEO4J_PASSWORD"] } else { "" }
}
if ([string]::IsNullOrWhiteSpace($Neo4jDatabase)) {
    $Neo4jDatabase = if ($env:NEO4J_DATABASE) { $env:NEO4J_DATABASE } elseif ($dotenv.ContainsKey("NEO4J_DATABASE")) { $dotenv["NEO4J_DATABASE"] } else { "neo4j" }
}

$inputPath = Resolve-InputMarkdownPath $InputMarkdown
$outputPath = Resolve-PathSafe $OutputDir
$generatorScript = Resolve-ProjectPath ".\generate_neo4j_cypher_from_markdown.py"
$exportScript = Resolve-ProjectPath ".\export_graph_to_cytoscape.py"

if (-not (Test-Path -LiteralPath $generatorScript)) {
    throw "Generator script not found: $generatorScript"
}

if (-not (Test-Path -LiteralPath $exportScript)) {
    throw "Export script not found: $exportScript"
}

if (-not (Test-Path -LiteralPath $inputPath)) {
    throw "Input markdown not found: $inputPath"
}

if (-not (Test-Path -LiteralPath $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath | Out-Null
}

$loadCypherScript = Resolve-ProjectPath ".\load_cypher_into_neo4j.py"
if (-not (Test-Path -LiteralPath $loadCypherScript)) {
    throw "Cypher loader script not found: $loadCypherScript"
}

$resolvedCypherShell = Resolve-CommandExecutable $CypherShellPath

$existingCypherNames = @{}
Get-ChildItem -Path $outputPath -Filter "*_neo4j_implementation.cypher" -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        $existingCypherNames[$_.Name] = $true
    }

Write-Host "[1/3] Generating timestamped Neo4j cypher from markdown..."
& $PythonCommand $generatorScript --input $inputPath --output-dir $outputPath
if ($LASTEXITCODE -ne 0) {
    throw "Cypher generation failed."
}

$generatedCypher = Get-ChildItem -Path $outputPath -Filter "*_neo4j_implementation.cypher" -File |
    Where-Object { -not $existingCypherNames.ContainsKey($_.Name) } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $generatedCypher) {
    throw "No newly generated '*_neo4j_implementation.cypher' file found in $outputPath."
}

Write-Host "[2/3] Resetting and loading Neo4j data..."
Write-Host "      File: $($generatedCypher.FullName)"
Write-Host "      Clearing existing nodes and relationships..."

$clearCypherPath = Join-Path $env:TEMP ("neo4j_clear_" + [Guid]::NewGuid().ToString("N") + ".cypher")
# Use ASCII to avoid BOM-related parse issues in downstream loaders.
Set-Content -LiteralPath $clearCypherPath -Value "MATCH (n) DETACH DELETE n;" -Encoding Ascii

try {
    if ($resolvedCypherShell) {
        & $resolvedCypherShell -a $Neo4jUri -u $Neo4jUser -p $Neo4jPassword -d $Neo4jDatabase -f $clearCypherPath
    }
    else {
        & $PythonCommand $loadCypherScript `
            --input $clearCypherPath `
            --uri $Neo4jUri `
            --user $Neo4jUser `
            --password $Neo4jPassword `
            --database $Neo4jDatabase
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Neo4j reset failed."
    }

    if ($resolvedCypherShell) {
        & $resolvedCypherShell -a $Neo4jUri -u $Neo4jUser -p $Neo4jPassword -d $Neo4jDatabase -f $generatedCypher.FullName
    }
    else {
        & $PythonCommand $loadCypherScript `
            --input $generatedCypher.FullName `
            --uri $Neo4jUri `
            --user $Neo4jUser `
            --password $Neo4jPassword `
            --database $Neo4jDatabase
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Neo4j load failed."
    }
}
finally {
    if (Test-Path -LiteralPath $clearCypherPath) {
        Remove-Item -LiteralPath $clearCypherPath -ErrorAction SilentlyContinue
    }
}

Write-Host "[3/3] Exporting graph to cytoscape_elements.json..."
$cytoscapeOutputPath = Resolve-ProjectPath "..\exports\cytoscape_elements.json"
$env:OUTPUT_FILE = $cytoscapeOutputPath
& $PythonCommand $exportScript
if ($LASTEXITCODE -ne 0) {
    throw "Cytoscape export failed."
}

Write-Host ""
Write-Host "Pipeline completed successfully."
Write-Host "- Loaded file: $($generatedCypher.Name)"
Write-Host "- Cytoscape output: $cytoscapeOutputPath"
