# Run with: .\commit_to_github.ps1 -CommitMessage "Your commit message"

param(
    [string]$CommitMessage = "Commit from script"
)

function Invoke-GitOrAbort {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )

    & git @Args
    if ($LASTEXITCODE -ne 0) {
        Write-Error $ErrorMessage
        exit 1
    }
}

function Push-HeadToBranch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName,
        [Parameter(Mandatory = $true)]
        [bool]$Force
    )

    $gitArgs = @('push', '-u', 'origin', "HEAD:refs/heads/$BranchName")
    if ($Force) {
        $gitArgs += '--force'
    }

    Invoke-GitOrAbort -Args $gitArgs -ErrorMessage "Push to branch '$BranchName' failed. Please check your branch name and authentication."
}

Write-Host ""
Write-Host "How do you want to update GitHub?"
Write-Host "  1) Commit latest changes (normal push)"
Write-Host "  2) COMPLETELY OVERWRITE remote with this device's state (force push, destructive)"

$choice = Read-Host "Enter 1 or 2"

if ($choice -ne "1" -and $choice -ne "2") {
    Write-Error "Invalid choice. Aborting."
    exit 1
}

$modeDescription = if ($choice -eq "1") {
    "normal commit & push"
} else {
    "FORCE PUSH that will overwrite the remote history"
}

Write-Host ""
Write-Host "You selected: $modeDescription"

if ($choice -eq "2") {
    Write-Host ""
    Write-Host "WARNING: This will overwrite the remote branch with your local branch."
    Write-Host "Any commits that exist only on GitHub (and not locally) will be LOST."
    $confirm = Read-Host "Type 'OVERWRITE' to confirm, or anything else to cancel"
    if ($confirm -ne "OVERWRITE") {
        Write-Error "Confirmation failed. Aborting without pushing."
        exit 1
    }
}

Write-Host ""
Write-Host "Ensuring Git remote 'origin' points to GitHub repo..."

# Check if 'origin' remote exists
$remoteExists = git remote | Where-Object { $_ -eq "origin" }

if ($remoteExists) {
    git remote set-url origin https://github.com/SingleColumn/social_situations_graph.git
} else {
    git remote add origin https://github.com/SingleColumn/social_situations_graph.git
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to configure git remote 'origin'. Aborting."
    exit 1
}

$currentBranch = (& git branch --show-current).Trim()
if (-not $currentBranch) {
    Write-Error "Could not determine the current local branch. Aborting."
    exit 1
}

$remoteHeadRef = (& git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null)
$remoteDefaultBranch = $null
if ($LASTEXITCODE -eq 0 -and $remoteHeadRef) {
    $remoteDefaultBranch = ($remoteHeadRef -replace '^origin/', '').Trim()
}

$upstreamRef = (& git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
$upstreamBranch = $null
if ($LASTEXITCODE -eq 0 -and $upstreamRef) {
    $upstreamBranch = ($upstreamRef -replace '^origin/', '').Trim()
}

$targetBranch = if ($remoteDefaultBranch) {
    $remoteDefaultBranch
} elseif ($upstreamBranch) {
    $upstreamBranch
} else {
    $currentBranch
}

Write-Host ""
Write-Host "Local branch: $currentBranch"
Write-Host "Remote target branch: $targetBranch"

Write-Host ""
Write-Host "Staging allowed files (as controlled by .gitignore)..."
git add -A :/

if ($LASTEXITCODE -ne 0) {
    Write-Error "git add failed. Aborting."
    exit 1
}

Write-Host ""
Write-Host "Creating commit..."
git commit -m $CommitMessage

if ($LASTEXITCODE -ne 0) {
    $workingTreeClean = (git status --porcelain)
    if ([string]::IsNullOrWhiteSpace(($workingTreeClean | Out-String))) {
        Write-Host "No staged changes to commit. Continuing to push current HEAD."
    } else {
        Write-Error "git commit failed. Aborting."
        exit 1
    }
}

Write-Host ""
if ($choice -eq "1") {
    Write-Host "Pushing local HEAD to 'origin/$targetBranch'..."
    Push-HeadToBranch -BranchName $targetBranch -Force $false
} else {
    $overwriteBranches = @($targetBranch, $currentBranch, 'master', 'main') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    Write-Host "FORCE pushing local HEAD to these remote branches: $($overwriteBranches -join ', ')"
    foreach ($branch in $overwriteBranches) {
        Push-HeadToBranch -BranchName $branch -Force $true
    }
}

Write-Host ""
Write-Host "Done. Project committed and pushed to GitHub."
