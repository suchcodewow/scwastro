$apikey = "pat.EeRjnXTnS4GrLG5VNNJZUw.67434db428e64616d95199f5.MpQxajcYPOrxAKtqSt9U"
# $account = "EeRjnXTnS4GrLG5VNNJZUw"

# Retrieve all account connectors
# reference: https://apidocs.harness.io/tag/Connectors#operation/getConnectorList
$headers = @{
    'x-api-key'    = $apikey
    'Content-Type' = "application/json"
}
# https://app.harness.io/ng/api/connectors/listV2?accountIdentifier=EeRjnXTnS4GrLG5VNNJZUw
# https://app.harness.io/ng/api/connectors?pageSize=1000
# $Body = @{
# filterType = "Connector"
# }
$response = Invoke-RestMethod -method Post -uri "https://app.harness.io/ng/api/connectors/listV2?pageSize=1000" -Headers $headers 
$connectorList = $response.data.content
write-host $connectorList.count
foreach ($connectorItem in $connectorList) {
    $connector = $connectorItem.connector
    if ($connector.name.contains("Arti")) {
        $connector.name
        $connector.spec
        $connector.spec.auth.spec.username
        $connector.spec.auth.spec.passwordRef
    }
}
