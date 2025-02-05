$apikey = "pat.EeRjnXTnS4GrLG5VNNJZUw.67434db428e64616d95199f5.MpQxajcYPOrxAKtqSt9U"
$account = $apikey.split(".")[1]

function Get-Secrets() {
    $headers = @{'x-api-key' = $apikey
        'Content-Type'       = "application/json" 
    }
    $Body = @{"filterType" = "Secret" } | Convertto-Json
    $response = Invoke-RestMethod -method Post -uri "https://app.harness.io/ng/api/v2/secrets/list/secrets?accountIdentifier=$account&pageSize=1000" -Headers $headers -body $Body
    return $response.data.content.secret

}

function Get-Connectors() {
    $headers = @{'x-api-key' = $apikey;'Content-Type' = "application/json" }
    $Body = @{filterType = "Connector" }
    $response = Invoke-RestMethod -method Post -uri "https://app.harness.io/ng/api/connectors/listV2?pageSize=1000" -Headers $headers 
    return $response.data.content.connector
}

function Get-CommaSeparatedSecrets() {
    $allSecrets = Get-Secrets
    # $allSecrets
    $commaSeparatedSecrets = ""
    foreach ($secret in $allSecrets) {
        if ($commaSeparatedSecrets.length -gt 0) {
            $commaSeparatedSecrets = "$commaSeparatedSecrets,"
        }
        $commaSeparatedSecrets = "$($commaSeparatedSecrets)account.$($secret.identifier);$($secret.type)"
    }
    return $commaSeparatedSecrets
    # $env:secrets = $commaSeparatedSecrets
}

$allConnectors = Get-Connectors
$allConnectors
foreach ($connector in $allConnectors) {
    Switch ($connector.type) {
        "GcpKms" {
            write-host "GcpKms"
        }

    }

}
# write-host "variable is: $env:ref"