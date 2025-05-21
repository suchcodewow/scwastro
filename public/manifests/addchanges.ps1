# Locations
$changesetPath = "changelog.yml"
$scriptsPath = "48-HourDeploys/scripts" # relative path to changeset i.e. "Deploy/Scripts"

# Repository Preferences
$allowedFileTypes = "*.sql"
$rollbackFolder = "Rollback" # relative folder where rollback script must be
$rollbackPreface = "Rollback." # filename preface required on each rollback file

# Administrative Settings
$kbLimit = "200" # (kb) limit is 64kb (with compression providing 4-5x reduction)
$changeLimit = "20" # (integer) limit how many changes deploy at once (lower values = easier troubleshooting)
$validRollbackRequired = $true

# !!!
# !!! Do not modify below !!!
# !!!
function New-ChangeYaml {
    $script:basePath = Get-Location
    write-host "[.] Script is running from: $basePath"
    if (!(Test-Path $changesetPath)) {
        Add-Content $changesetPath -Value "databaseChangeLog:"
        write-host [.] Created new file: $changesetPath
    }
}
function Get-ExecutedChanges {
    # Return existing folders in changeset
    if (Test-Path $changesetPath) {
        $executedChanges = Get-Content $changesetPath | Where-Object { $_ -match 'id: ' } | ForEach-Object { $_.split(":")[1].trim() }
        write-host "[.] Found $($executedChanges.count) existing changes in $changesetPath."
        return $executedChanges
    }
    write-host "[?] $changesetPath not found."
    return @()
}

function Get-RepoChanges {
    # Return all folders in this repository
    $AllItems = Get-ChildItem -Path $scriptsPath -Depth 1 -include $allowedFileTypes | Sort-Object -property CreationTime | select-object -Property @{Label = "AuthorID";Expression = { $_.FullName } }, @{Label = "ChangeID";Expression = { $_.Basename } }, @{Label = "FileType";Expression = { $_.Extension } }, @{Label = "ValidPath"; Expression = { $false } }, @{Label = "ChangeSize"; Expression = { [int]0 } },@{Label = "ValidRollbackPath"; Expression = { $false } },  @{Label = "RollbackSize"; Expression = { [int]0 } }
    # Possibly saucier way to get 1 subfolder up but for now...
    $Allitems | ForEach-Object {
        $slashFix = $_.AuthorID.replace("\","/")
        $_.AuthorID = $slashFix.split("/")[-2]
    }
    write-host "[.] Found $($Allitems.count) changes in the $scriptsPath repository."
    return $Allitems
}

function New-Changes {
    # Build a list of all new changes (remove any previously listed changes)
    $existingChanges = Get-ExecutedChanges
    $newChanges = Get-RepoChanges | Where-Object { $_.ChangeID -notin $existingChanges }
    write-host "[.] $($newChanges.count) repository changes are new."
    return $newChanges
}

function Add-Checks {
    # Checks new changes for: valid file path, corresponding rollback
    $changeList = New-Changes
    foreach ($change in $changeList) {
        $changePath = $scriptsPath + "/" + $change.AuthorID + "/" + $change.ChangeID + $change.FileType
        if (Test-Path($changePath)) {
            $change.ValidPath = $true
            $change.ChangeSize = [Math]::Round((get-childitem -path $changePath | Measure-Object -Property Length -Sum | Select-Object -expandproperty Sum))

        }
        $rollbackPath = $scriptsPath + "/" + $change.AuthorID + "/" + $rollbackFolder + "/" + $rollbackPreface + $change.ChangeID + $change.FileType
        if (Test-Path($rollbackPath)) { 
            $change.ValidRollbackPath = $true 
            $change.RollbackSize = [Math]::Round((get-childitem -path $rollbackPath | Measure-Object -Property Length -Sum | Select-Object -expandproperty Sum))
        }
    }
    return $changeList
}

function Invoke-Changes {
    $checkedChangeList = Add-Checks
    $changeSetSize = 0
    $rollbackSetSize = 0
    $changeCounter = 1
    foreach ($proposedChange in $checkedChangeList) {
        # Check if rollback path is valid
        if (!$proposedChange.ValidRollbackPath -and $validRollbackRequired) {
            write-host "[X] $($proposedChange.AuthorID) $($proposedChange.ChangeID) rollback script missing: $scriptsPath/$($proposedChange.AuthorID)/$rollbackFolder/$rollbackPreface$($proposedChange.ChangeID)$($proposedChange.FileType)"
            continue
        }
        # Check if there is room in this changeset
        $changeinKB = $proposedChange.ChangeSize / 1024
        $remainingLimit = [math]::Round($kblimit - $changeSetSize)
        if ($changeinKB -gt $remainingLimit) {
            write-host "[-] skipping $($proposedChange.AuthorID) $($proposedChange.ChangeID): $([math]::Round($changeinKB,2))KB is larger than remaining limit of $($remainingLimit)KB"
            continue
        }
        # Check if there is room for rollback
        $rollbackinKB = $proposedChange.RollbackSize / 1024
        $remainingRollbackLimit = [math]::Round($kblimit - $rollbackSetSize)
        if ($rollbackinKB -gt $remainingRollbackLimit) {
            write-host "[-] skipping $($proposedChange.AuthorID) $($proposedChange.ChangeID): $([math]::Round($rollbackinKB,2))KB is larger than remaining rollback limit of $($remainingRollbackLimit)KB"
            continue
        }
        # Check change count size
        if ($changeCounter -gt $changeLimit) {
            write-host "[-] skipping $($proposedChange.AuthorID) $($proposedChange.ChangeID): Maximum changeset of $changeLimit reached."
            continue
        }
        # Check if there is room for rollback
        Add-Content -Path $changesetPath -Value "  - changeSet:"
        Add-Content -Path $changesetPath -Value "      id: $($proposedChange.changeID)"
        Add-Content -Path $changesetPath -Value "      author: $($proposedChange.AuthorID)"
        Add-Content -Path $changesetPath -Value "      changes:"
        Add-Content -Path $changesetPath -Value "        - sqlFile:"
        Add-Content -Path $changesetPath -Value "            path: $scriptsPath/$($proposedChange.AuthorID)/$($proposedChange.ChangeID)$($proposedChange.FileType)"
        Add-Content -Path $changesetPath -Value "            endDelimiter: \nGO"
        if ($proposedChange.ValidRollbackPath) {
            Add-Content -Path $changesetPath -Value "      rollback:"
            Add-Content -Path $changesetPath -Value "        - sqlFile:"
            Add-Content -Path $changesetPath -Value "            path: $scriptsPath/$($proposedChange.AuthorID)/$rollbackFolder/$rollbackPreface$($proposedChange.ChangeID)$($proposedChange.FileType)"
            Add-Content -Path $changesetPath -Value "            endDelimiter: \nGO"
        }                                     
        write-host "[.] Change #$changeCounter $($proposedChange.AuthorID) $($proposedChange.ChangeID) added. Total changeset size: $([math]::Round($changeSetSize))KB & rollback changeset size: $([math]::Round($rollbackSetSize))KB"
        $changeSetSize += $changeinKB
        $rollbackSetSize += $rollbackinKB
        $changeCounter++
    }
}
New-ChangeYaml
Invoke-Changes
#Add-Checks