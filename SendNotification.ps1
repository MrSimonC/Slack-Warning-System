[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Sends json to Azure Function "Notifier" which translates in to a more complex Teams Message
# Note: Forget Emojis here! Powershell is a nightmare for that kind of "international" stuff
# Requires: 
#  Webhook variable
function Send-Notification ([string]$client, [string]$text, [string]$title=$null, [string]$colour= $null
) {
    # format json message
    $payload = @{
        "client" = $client
        "text" = $text
        "title" = $title
        "colour" = $colour
    }

    # Debug:
    # Write-Output (ConvertTo-Json -Compress -InputObject $payload)

    # send notification
    Invoke-WebRequest `
    -Body (ConvertTo-Json -Compress -InputObject $payload) `
    -Method Post `
    -Uri $Webhook | Out-Null
}
