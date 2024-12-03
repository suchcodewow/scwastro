# VSCODE: ctrl/cmd+k+1 folds all functions, ctrl/cmd+k+j unfold all functions. Check '.vscode/launch.json' for any current parameters

# Core Functions
function Send-Update {
    # Handle output to screen & log, execute commands to cloud systems and return results
    param(
        [string] $content, # Message content to log/write to screen
        [int] $type, # [0/1/2] log levels respectively: debug/info/errors, info/errors, errors
        [string] $run, # Run a command and return result
        [switch] $append, # [$true/false] skip the newline (next entry will be on same line)
        [switch] $errorSuppression, # use this switch to suppress error output (useful for extraneous warnings)
        [switch] $outputSuppression, # use to suppress normal output
        [switch] $whatIf # do NOT run command, just SHOW for troubleshooting
    )
    $Params = @{}
    if ($whatIf) { $whatIfComment = "!WHATIF! " }
    if ($run) {
        $Params['ForegroundColor'] = "Magenta"; $start = "[$whatIfComment>]"
    }
    else {
        Switch ($type) {
            0 { $Params['ForegroundColor'] = "DarkBlue"; $start = "[.]" }
            1 { $Params['ForegroundColor'] = "DarkGreen"; $start = "[-]" }
            2 { $Params['ForegroundColor'] = "DarkRed"; $start = "[X]" }
            default { $Params['ForegroundColor'] = "Gray"; $start = "" }
        }
    }
    # Format the command to show on screen if user wants to see it
    if ($run -and $showCommands) { $showcmd = " [ $run ] " }
    if ($currentLogEntry) { $screenOutput = "$content$showcmd" } else { $screenOutput = "   $start $content$showcmd" }
    if ($append) { $Params['NoNewLine'] = $true; $script:currentLogEntry = "$script:currentLogEntry $content$showcmd"; }
    if (-not $append) {
        #This is the last item in-line.  Write it out if log exists
        if ($logFile) {
            "$(get-date -format "yyyy-MM-dd HH:mm:ss"): $currentLogEntry $content$showcmd" | out-file $logFile -Append
        }
        #Reset inline recording
        $script:currentLogEntry = $null
    }
    # output if user wants to see this level of content
    if ($type -ge $outputLevel) {
        write-host @Params $screenOutput
    }
    if ($whatIf) { $run;return }
    if ($run -and $errorSuppression -and $outputSuppression) { return invoke-expression $run 1>$null }
    if ($run -and $errorSuppression) { return invoke-expression $run 2>$null }
    if ($run -and $outputSuppression) { return invoke-expression $run 1>$null }
    if ($run) { return invoke-expression $run }
}
function Get-Prefs($scriptPath) {
    # Do the things for the command line switches selected
    if ($help) { Get-Help }
    if ($verbose) { $script:outputLevel = 0 } else { $script:outputLevel = 1 }
    if ($cloudCommands) { $script:showCommands = $true } else { $script:showCommands = $false }
    if ($logReset) { $script:retainLog = $false } else { $script:retainLog = $true }
    if ($aws) { $script:useAWS = $true }
    if ($azure -eq $true) { $script:useAzure = $true }
    if ($gcp) { $script:useGCP = $true }
    if ($multiUserMode) { $script:multiUserMode = $true }
    # If no cloud selected, use all
    if ((-not $useAWS) -and (-not $useAzure) -and (-not $useGCP)) { $script:useAWS = $true; $script:useAzure = $true; $script:useGCP = $true }
    # Set Script level variables and housekeeping stuffs
    [System.Collections.ArrayList]$script:providerList = @()
    [System.Collections.ArrayList]$script:choices = @()
    $script:currentLogEntry = $null
    $script:muCreateClusters = $false
    $script:muCreateWebApp = $false
    $script:muDeployDynatrace = $false
    # Any yaml here will be available for installation- file should be namespace (i.e. x.yaml = x namescape)
    $script:ProgressPreference = "SilentlyContinue"
    if ($scriptPath) {
        $script:logFile = "$($scriptPath).log"
        Send-Update -t 0 -c "Log: $logFile"
        if ((test-path $logFile) -and -not $retainLog) {
            Remove-Item $logFile
        }
        $script:configFile = "$($scriptPath).conf"
        Send-Update -t 0 -c "Config: $configFile"
    }
    if ($outputLevel -eq 0) {
        $script:choiceColumns = @("Option", "description", "current", "key", "callFunction", "callProperties")
        $script:providerColumns = @("option", "provider", "name", "identifier", "userid", "default")
    }
    else {
        $script:choiceColumns = @("Option", "description", "current")
        $script:providerColumns = @("option", "provider", "name")
    }
    # Load preferences/settings.  Access with $config variable anywhere.  Set-Prefs automatically updates $config variable and saves to file
    # Set with Set-Prefs function
    if ($scriptPath) {
        $script:configFile = "$scriptPath.conf"
        if (Test-Path $configFile) {
            Send-Update -c "Reading config" -t 0
            $script:config = Get-Content $configFile -Raw | ConvertFrom-Json -AsHashtable
        }
        else {
            $script:config = @{}
            $config["schemaVersion"] = "2.0"
            if ($MyInvocation.MyCommand.Name) {
                $config | ConvertTo-Json | Out-File $configFile
                Send-Update -c "CREATED config" -t 0
            }
        }
    }
    Set-Prefs -k userCount -v $users
    write-host
}
function Set-Prefs {
    param(
        $u, # Add this value to a user's settings (mostly for mult-user setup sweetness)
        $k, # key
        $v # value
    )
    # Create Users hashtable if needed
    if (-not $config.Users) { $config.Users = @{} }
    if ($u) {
        # Focus on user subkey
        if ($k) {
            # Create User nested hashtable if needed
            if (-not $config.Users.$u) { $config.Users.$u = @{} }
            if ($v) {
                # Update User Value
                Send-Update -c "Updating $u user key: $k -> $v" -t 0
                $config.Users.$u[$k] = $v 
            }
            else {
                if ($k -and $config.Users.$u.containsKey($k)) {
                    # Attempt to delete the user's key
                    Send-Update -c "Deleting $u user key: $k" -t 0
                    $config.Users.$u.remove($k)
                }
                else {
                    Send-Update -c "$u Key didn't exist: $k" -t 0
                }
            }
        }
        else {
            if ($config.Users.$u) {
                # Attempt to remove the entire user
                Send-Update -c "Removing $u user" -t 0
                $config.Users.remove($u)
            }
            else {
                Send-Update -c "User $u didn't exists" -t 0
            }
        }
    }
    else {
        # Update at main schema level
        if ($v) {
            Send-Update -c "Updating key: $k -> $v" -t 0
            $config[$k] = $v 
        }
        else {
            if ($k -and $config.containsKey($k)
            ) {
                Send-Update -c "Deleting config key: $k" -t 0
                $config.remove($k)
            }
            else {
                Send-Update -c "Key didn't exist: $k" -t 0
            }
        }     
    }
    if ($MyInvocation.MyCommand.Name) {
        $config | ConvertTo-Json | Out-File $configFile
    }
    else {
        Send-Update -c "No command name, skipping write" -t 0
    }
}
function Add-Choice() {
    #example: Add-Choice -k 'key' -d 'description' -c 'current' -f 'function' -p 'parameters'
    param(
        [string] $key, # key identifying this choice, unique only
        [string] $description, # description of item
        [string] $current, # current selection of item, if applicable
        [string] $function, # function name to call if changing item
        [object] $parameters # parameters needed in the function
    )
    # If this key exists, delete it and anything that followed
    Send-Update -c "Add choice: $key" -t 0
    $keyOption = $choices | Where-Object { $_.key -eq $key } | select-object -expandProperty Option -first 1
    if ($keyOption) {
        $staleOptions = $choices | Where-Object { $_.Option -ge $keyOption }
        $staleOptions | foreach-object { Send-Update -c "Removing $($_.Option) $($_.key)" -t 0; $choices.remove($_) }
    }
    $choice = New-Object PSCustomObject -Property @{
        Option         = $choices.count + 1
        key            = $key
        description    = $description
        current        = $current
        callFunction   = $function
        callProperties = $parameters
        

    }
    [void]$choices.add($choice)
}
function Get-Choice() {
    # Present list of options and get selection
    write-output $choices | sort-object -property Option | format-table $choiceColumns | Out-Host
    $cmd_selected = read-host -prompt "Which option to execute? [<enter> to quit]"
    if (-not($cmd_selected)) {

        write-host "buh bye!`r`n" | Out-Host
        exit
    }
    if ($cmd_selected -eq 0) { Get-Quote }
    return $choices | Where-Object { $_.Option -eq $cmd_selected } | Select-Object -first 1 
}
Function Get-RandomAlphanumericString {
	
    [CmdletBinding()]
    Param (
        [int] $length = 6
    )

    Begin {
    }

    Process {
        Write-Output (( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length | ForEach-Object { [char]$_ }) )).toLower()
    }	
}

# Provider Functions
function Add-Provider() {
    param(
        [string] $p, # provider
        [string] $n, # name of item
        [string] $i, # item unique identifier
        [switch] $d, # [$true/$false] default option
        [string] $u # unique user identifier (for creating groups/clusters)
    )
    #---Add an option selector to item then add to provider list
    $provider = New-Object PSCustomObject -Property @{
        provider   = $p
        name       = $n
        identifier = $i
        default    = $d
        userid     = $u
        option     = $providerLIst.count + 1
    }
    [void]$providerList.add($provider)
}
function Get-Providers() {
    Send-Update -content "Gathering provider options... " -t 1 -a
    $providerList.Clear()
    # AZURE
    if ($useAzure) {
        Send-Update -content "Azure:" -t 1 -a
        if (get-command 'az' -ea SilentlyContinue) {
            $azureSignedIn = az ad signed-in-user show 2>$null 
        }
        else { Send-Update -content "NA " -t 1 -a }
        if ($azureSignedIn) {
            #Azure connected, get current subscription
            $currentAccount = az account show --query '{name:name,email:user.name,id:id}' | Convertfrom-Json
            $allAccounts = az account list --query '[].{name:name, id:id}' --only-show-errors | ConvertFrom-Json
            foreach ($i in $allAccounts) {
                $Params = @{}
                if ($i.id -eq $currentAccount.id) { $Params['d'] = $true }
                Add-Provider @Params -p "Azure" -n "subscription: $($i.name)" -i $i.id -u (($currentAccount.email).split("@")[0]).replace(".", "").ToLower()
            }
        }
        Send-Update -content "$($allAccounts.count) " -a -t 1
    }
    # AWS
    if ($useAWS) {
        Send-Update -content "AWS:" -t 1 -a
        if (get-command 'aws' -ea SilentlyContinue) {
            # below doesn't work for non-admin accounts
            # instead, check environment variables for a region
            $awsRegion = $env:AWS_REGION
            if (-not $awsRegion) {
                # No region in environment variables, trying pulling from local config
                $awsRegion = aws configure get region
            }
            if ($awsRegion) {
                # For workshops, using ARN maybe?
                $arnCheck = (aws sts get-caller-identity --output json 2>$null | Convertfrom-JSon).Arn
                if ($arnCheck) {
                    $awsSignedIn = $arnCheck.split("/")[1]
                }
                if ($awsSignedIn -eq "dtRoleAdvancedUser") {
                    # if on Dynatrace account, sub in name instead of dtRoleAdvancedUser
                    (aws sts get-caller-identity --output json 2>$null | Convertfrom-JSon).UserId -match "-(.+)\.(.+)@" 1>$null
                    if ($Matches.count -eq 3) {
                        $awsSignedIn = "$($Matches[1])$($Matches[2])"
                    }
                }
                # else {
                #     # No Email- try alternate method to get a unique identifier
                #     $awsSts = aws sts get-caller-identity --output json 2>$null | Convertfrom-JSon
                #     if ($awsSts) {
                #         $awsSignedIn = $awsSts.UserId.subString(0, 6)
                #     }
                # }
            }
            if ($awsSignedIn) {
                Add-Provider -d -p "AWS" -n "$awsRegion/$($awsSignedIn.ToLower())" -i $awsRegion -u $($awsSignedIn.ToLower())
                Send-Update -c "1 " -a -t 1
            }
            else {
                # Total for AWS is just 1 or 0 for now so use this toggle
                Send-Update -c "0 " -a -t 1
            }
        }
        else { Send-Update -c "NA " -t 1 -a }
    }
    # GCP
    if ($useGCP) {
        Send-Update -c "GCP:" -t 1 -a
        if (get-command 'gcloud' -ea SilentlyContinue) {
            $accounts = gcloud auth list --format="json" | ConvertFrom-Json 
            if ($accounts.count -gt 0) {
                foreach ($i in $accounts) {
                    $Params = @{}
                    if ($i.status -eq "ACTIVE") { $Params['d'] = $true } 
                    Add-Provider @Params -p "GCP" -n "account: $($i.account)" -i $i.account -u (($i.account).split("@")[0]).replace(".", "").ToLower()
                }
                Send-Update -c "$($accounts.count) " -a -t 1
            }
            else {
                # Total for AWS is just 1 or 0 for now so use this toggle
                Send-Update -c "0 " -a -t 1
            }
        }
        else { Send-Update -content "NA " -t 1 -a }
        
    }
    # Done getting options
    Send-Update -c " " -type 1
    #Take action based on # of providers
    if ($providerList.count -eq 0) { write-output "`nCouldn't find a valid target cloud environment. `nLogin to Azure (az login), AWS, or GCP (gcloud auth login) and retry.`n"; exit }
    #If there's one default, set it as the current option
    $providerDefault = $providerList | Where-Object default -eq $true
    if ($providerDefault.count -eq 1) {
        # One provider- preload it
        Set-Provider -preset $providerDefault
    }
    else {
        # Select from 2+ default providers
        Set-Provider
    }
}
function Set-Provider() {
    param(
        [object] $preset # optional preset to bypass selection
    )
    $providerSelected = $preset
    while (-not $providerSelected) {
        write-output $providerList | sort-object -property Option | format-table $providerColumns | Out-Host
        $newProvider = read-host -prompt "Which environment to use? <enter> to cancel"
        if (-not($newProvider)) {
            return
        }
        $providerSelected = $providerList | Where-Object { $_.Option -eq $newProvider } | Select-Object -first 1
        if (-not $providerSelected) {
            write-host -ForegroundColor red "`r`nY U no pick valid option?" 
        }
    }
    $functionProperties = @{provider = $providerSelected.Provider; id = $providerSelected.identifier.tolower(); userid = $providerSelected.userid.tolower() }

    # Reset choices
    # Add option to change destination again
    Add-Choice -k "TARGET" -d "Switch Cloud Provider" -c "$($providerSelected.Provider) $($providerSelected.Name)" -f "Set-Provider" -p $functionProperties
    # build options for specified provider
    switch ($providerSelected.Provider) {
        "Azure" {
            # Set the Azure subscription
            Send-Update -t 1 -c "Azure: Set Subscription" -r "az account set --subscription $($providerSelected.identifier)"
            Set-Prefs -k "provider" -v "azure"
            Add-AzureSteps 
        }
        "AWS" {
            Send-Update -t 1 -c "AWS: Set region"
            Set-Prefs -k "provider" -v "aws"
            Add-AWSSteps 
        }
        "GCP" { 
            # set the GCP Project
            Send-Update -OutputSuppression -t 1 -c "GCP: Set Project" -r "gcloud config set account '$($providerSelected.identifier)' --no-user-output-enabled"
            Set-Prefs -k "provider" -v "gcp"
            Add-GCPSteps 
        }
    }
}

# GCP Functions
function Add-GCPSteps {
    # Add GCP specific steps
    $userProperties = $choices | where-object { $_.key -eq "TARGET" } | select-object -expandproperty callProperties
    # get current project
    $currentProject = Send-Update -content "GCP: Get Current Project" -t 0 -r "gcloud config get-value project"
    # if there is one, can the current account access itis it valid for this account?
    if ($currentProject) {
        # project exists, check if current account can access it
        $validProject = Send-Update -c "GCP: Project found, is it valid?" -a -t 0 -r "gcloud projects list --filter $currentProject --format='json' | Convertfrom-Json"
    }
    if ($validProject.count -eq 1) {
        # Exactly one valid project.  Offer option to change it
        Send-Update -content "yes" -type 0
        if ($currentProject -ne $validProject.projectid) {
            Send-Update -c "Switching from Project # to Id" -t 0 -r "gcloud config set project $($validProject.Projectid) "
        }
        Add-Choice -k "GPROJ" -d "Change Project" -c $($validProject.projectId) -f "Set-GCPProject"
    }
    else {
        Add-Choice -k "GPROJ" -d "Required: Select GCP Project" -f "Set-GCPProject"
        return
    }
    # Add region if/when needed
    # if (!$config.GCPRegion) {
    #     Add-Choice -k "GREGION" -d "Required: Select Region" -f "Set-GCPRegion"
    #     return
    # }
    # else {
    #     Add-Choice -k "GREGION" -d "Change Region" -c $($config.RCPRegion) -f "Set-GCPRegion"
    # }
    # $currentRegion = Send-Update -content "GCP: Get Current Region" -t 0 -r "gcloud config get-value region"
    
 
    Add-CommonSteps
}
function Set-GCPProject {
    # set the default project
    $projectList = gcloud projects list --format='json' --sort-by name | ConvertFrom-Json
    $counter = 0; $projectChoices = Foreach ($i in $projectList) {
        $counter++
        New-object PSCustomObject -Property @{Option = $counter; name = $i.name; projectId = $i.projectId }
    }
    $projectChoices | sort-object -property Option | format-table -Property Option, name, projectId | Out-Host
    while (-not $projectId) {
        $projectSelected = read-host -prompt "Which project? <enter> to cancel"
        if (-not $projectSelected) { return }
        $projectId = $projectChoices | Where-Object -FilterScript { $_.Option -eq $projectSelected } | Select-Object -ExpandProperty projectId -first 1
        if (-not $projectId) { write-host -ForegroundColor red "`r`nHey, just what you see pal." }
    }
    Send-Update -t 1 -content "GCP: Select Project" -run "gcloud config set project $projectId" -e
    Add-GCPSteps
}
function Set-GCPRegion {
    # set the default project
    $projectList = gcloud projects list --format='json' --sort-by name | ConvertFrom-Json
    $counter = 0; $projectChoices = Foreach ($i in $projectList) {
        $counter++
        New-object PSCustomObject -Property @{Option = $counter; name = $i.name; projectId = $i.projectId }
    }
    $projectChoices | sort-object -property Option | format-table -Property Option, name, projectId | Out-Host
    while (-not $projectId) {
        $projectSelected = read-host -prompt "Which project? <enter> to cancel"
        if (-not $projectSelected) { return }
        $projectId = $projectChoices | Where-Object -FilterScript { $_.Option -eq $projectSelected } | Select-Object -ExpandProperty projectId -first 1
        if (-not $projectId) { write-host -ForegroundColor red "`r`nHey, just what you see pal." }
    }
    Send-Update -t 1 -content "GCP: Select Project" -run "gcloud config set project $projectId" -e
    Add-GCPSteps
}
function Get-GCPCluster {
    # Load the kubectl credentials
    # $env:USE_GKE_GCLOUD_AUTH_PLUGIN = True
    Send-Update -c "Get cluster creds" -t 1 -r "gcloud container clusters get-credentials  --zone $($config.gcpzone) $($config.gcpclustername)"
}
function Add-GCRDelegate {
    $initScript = "curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz && tar -xf google-cloud-cli-linux-x86_64.tar.gz && ./google-cloud-sdk/install.sh && ./google-cloud-sdk/bin/gcloud init"
    # Get unique name
    $nameExists = $true
    do {
        $delegateName = "harness-delegate-$(Get-RandomAlphanumericString)"
        $nameExists = Send-Update -t 1 -c "Checking name $delegateName" -r "gcloud run services list --filter=SERVICE=$delegateName --format=json | Convertfrom-Json"
    } while ($nameExists)
    Send-Update -t 1 -c "Deploying Delegate" -r "gcloud run deploy $delegateName --memory=4Gi --port=3460 --image=harness/delegate:24.09.83909 --no-allow-unauthenticated --min-instances=1 --max-instances=1 --no-cpu-throttling --set-env-vars 'JAVA_OPTS=$($config.Harness_JAVA_OPTS),ACCOUNT_ID=$($config.Harness_ACCOUNT_ID),DELEGATE_NAME=$delegateName,NEXT_GEN=true,DEPLOY_MODE=KUBERNETES,DELEGATE_TYPE=KUBERNETES,CLIENT_TOOLS_DOWNLOAD_DISABLED=true,DYNAMIC_REQUEST_HANDLING=false,DELEGATE_TOKEN=$($config.Harness_DELEGATE_TOKEN),LOG_STREAMING_SERVICE_URL=$($config.Harness_LOG_STREAMING_SERVICE_URL),MANAGER_HOST_AND_PORT=$($config.Harness_MANAGER_HOST_AND_PORT),INIT_SCRIPT=$initScript'"
    Set-Prefs -k gcrDelegate -v $nameExists
}
function Add-GCRMySql {
    # Get unique name
    $nameExists = $true
    do {
        $delegateName = "globalcorp-catalogdb-$(Get-RandomAlphanumericString)"
        $nameExists = Send-Update -t 1 -c "Checking name $delegateName" -r "gcloud run services list --filter=SERVICE=$delegateName --format=json | Convertfrom-Json"
    } while ($nameExists)
    Send-Update -t 1 -c "Deploying CatalogDB" -r "gcloud run deploy $delegateName --memory=2Gi --port=3306 --image=mysql --allow-unauthenticated --min-instances=1 --max-instances=1 --no-cpu-throttling --set-env-vars=MYSQL_USER=api,MYSQL_PASSWORD=password,MYSQL_ROOT_PASSWORD=password,MYSQL_DATABASE=catalogDb"
    Set-Prefs -k gcrMySql -v $nameExists
}

# Application Functions
function Get-YamlValues() {
    if (!(Test-Path harness-delegate.yml)) {
        Send-Update -t 2 -c "Harness-delegate.yaml not found in this folder. Deployment options will be limited."
        return
    }
    Send-Update -t 1 -c "Getting Harness values from harness-delegate.yml"
    $yamlFile = Get-Content -Path harness-delegate.yml -Raw
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module powershell-yaml -Repository PSGallery
    Import-Module powershell-yaml
    $yaml = ConvertFrom-Yaml $yamlFile -AllDocuments
    $yamlEnv = $yaml.spec.template.spec.containers.env
    if (!$yamlEnv) { 
        Send-Update -t 2 -c "No environment variables found in delegate yaml."
        return $false 
    }
    # Environment values
    foreach ($item in $yamlEnv) {
        Set-Prefs -k "Harness_$($item.name)" -v $item.value
    }
    # Secret values
    Set-Prefs -k "Harness_DELEGATE_TOKEN" -v $yaml.data.DELEGATE_TOKEN
    return $true
}
function Add-CommonSteps() {
    $yamlValues = Get-YamlValues
    #Add functions valid when we have Harness ID and tokens
    if ($yamlValues) {
        # GCP specific options
        if ($config.provider = "GCP") {
            Add-Choice -k "G-GCR-DELE" -d "Deploy Harness Delegate to Cloud Run" -f "Add-GCRDelegate" -c $config.gcrDelegate
            Add-Choice -k "G-GCR-MYSQL" -d "Deploy CatalogDB to Cloud Run" -f Add-GCRMySql -c $config.gcrMySql
        }
    }
}
function Set-HarnessConfig {
    While (-not $HarnessToken) {
        # Get account ID
        While (-not $cleanaccountID) {
            $accountID = read-Host -Prompt "Your Harness Account ID: <enter> to cancel"
            if (-not $accountID) {
                return
            }
            if ($Matches) { Clear-Variable Matches }
            $accountID -match '\w{22}' | Out-Null
            if ($Matches) { $cleanaccountID = $Matches[0] }
            else { write-host "account ID should be exactly 22 alphanumeric characters." }
        }
        # Get Token
        While (-not $cleanToken) {
            $token = read-Host -Prompt "API Token: <enter> to cancel"
            if (-not $token) {
                return
            }
            if ($Matches) { Clear-Variable Matches }
            $token -match '^pat.{68}' | Out-Null
            if ($Matches) {
                $cleanToken = $Matches[0]
                Set-Prefs -k writeToken -v $cleanToken
            }
            else {
                write-host "Tokens start with 'pat' and then 68 characters."
            }
    
        }
        $headers = @{
            # accept         = "application/json; charset=utf-8"
            "Content-Type"    = "application/json"
            "x-api-key"       = $token
            "Harness-Account" = $cleanaccountID
        }
        # $data = @{
        #     scopes              = @("activeGateTokenManagement.create", "entities.read", "settings.read", "settings.write", "DataExport", "InstallerDownload", "logs.ingest", "openTelemetryTrace.ingest")
        #     name                = "SCW Token"
        #     personalAccessToken = $false
        # }
        # $body = $data | ConvertTo-Json
        # Try {
        #     $response = Invoke-RestMethod -Method Post -Uri "https://$accountURL/api/v2/apiTokens" -Headers $headers -Body $body
        # }
        # Catch {
        #     # The noise, ma'am.  Suppress the noise.
        #     write-host "Error Code: " $_.Exception.Response.StatusCode.value__
        #     Write-Host "Description:" $_.Exception.Response.StatusDescription
        # }
        # 'https://app.harness.io/v1/orgs?org=string&search_term=string&page=0&limit=20&sort=name&order=ASC'
        $response = Invoke-RestMethod -Method Get -Uri 'https://app.harness.io/v1/orgs?page=0&limit=20' -Headers $headers
        $response
        $HarnessToken = "your mom"
        # if ($response.token) {
        #     # API Token has to be base64. #PropsDaveThomas<3
        #     $k8stoken = $response.token
        #     Set-Prefs -k accountID -v $accountURL
        #     Set-Prefs -k writeToken -v $token
        #     Set-Prefs -k k8stoken -v $k8stoken
        #     # Set-Prefs -k base64Token -v $base64Token
        #     Add-DynakubeYaml -t $k8stoken -u $accountURL -c "k8s$($choices.callProperties.userid)"
        # }
        # else {
        #     write-host "Failed to connect to $accountURL"
        #     Clear-Variable cleanaccountID
        #     Clear-Variable cleanToken
        #     Set-Prefs -k accountID
        #     Set-Prefs -k writeToken
        #     Set-Prefs -k k8stoken
        # }
    }
    Set-Prefs -k HarnessAccount -v $cleanaccountID
    Set-Prefs -k HarnessToken -v $token
    # Add-CommonSteps
}

# Startup
Get-Prefs($Myinvocation.MyCommand.Source)
Get-Providers
while ($choices.count -gt 0) {
    $cmd = Get-Choice($choices)
    if ($cmd) {
        Invoke-Expression $cmd.callFunction
    }
    else { write-host -ForegroundColor red "`r`nY U no pick existing option?" }
}
# Set-HarnessConfig
