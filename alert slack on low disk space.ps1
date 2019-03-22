Set-StrictMode -Version Latest

# find out current working directory
function Get-ScriptDirectory
{
    Split-Path $script:MyInvocation.MyCommand.Path
}

# get ip address
function Get-IPAddress-Of-LocalHost() {
    return (Test-Connection -ComputerName (hostname) -Count 1  | Select-Object -ExpandProperty IPV4Address).IPAddressToString
}

# start logging (disabled)
# $LogPath = Get-ScriptDirectory | Join-Path -ChildPath "log.txt"
# Start-Transcript -path $LogPath -append
Write-Output "Script is running ok"

# global flag variables
$GlobalFlagPath = Get-ScriptDirectory | Join-Path -ChildPath "flag.txt"
$GlobalFlag = "messageAlreadySent"

# client specific variables
# initial values to be overriden by clientSpecific.ps1
$server = "" # server name for slack message
$client = "" # used for azure function to map to a Teams webhook
$Webhook = "" # Azure function entry point, handed to SendNotification.ps1
. (Get-ScriptDirectory | Join-Path -ChildPath clientSpecific.ps1)
. (Get-ScriptDirectory | Join-Path -ChildPath SendNotification.ps1)

# Checks flag file for e.g. "messageAlreadySent". Returns true/false
function Get-Message-Already-Sent ([string]$FlagPath=$GlobalFlagPath, [string]$Flag=$GlobalFlag) {
    if (Test-Path $FlagPath) {
        foreach ($item in Get-Content $FlagPath)
        {
            if ($item -eq $Flag) {
                return $true
            }
        }            
    }
    return $false
}

# Set or removes the flag contents
function Set-Message-Already-Sent ([string]$FlagPath=$GlobalFlagPath, [string]$Flag=$GlobalFlag) {
     $Flag | Set-Content -Path $FlagPath
}

function Send-Slack ([string]$mainMessage, [string]$colour
) {
    # format slack message
    $payload = @{
        "username" = "Server-bot"
        "icon_emoji" = ":floppy_disk:"
        "attachments" = @(@{
            "fallback" = $mainMessage
            "text" = $mainMessage
            "color" = if ($colour) {$colour} else {"#ff8c00"}
        })
    }
    # send slack notification
    Invoke-WebRequest `
    -Body (ConvertTo-Json -Compress -InputObject $payload) `
    -Method Post `
    -Uri $SlackWebhook | Out-Null
}

[array]$diskSummaryArray = $null
$ip = Get-IPAddress-Of-LocalHost

# check each disk for low space
foreach ($disk in Get-WmiObject Win32_LogicalDisk) {
    $diskName = $disk | Select-Object Name  | Select-Object -ExpandProperty "Name"
    $free = $disk | Select-Object FreeSpace
    $freespace = [Math]::Round($free.Freespace / 1GB)
    
    # escape any CD Drives
    if ($freespace -eq 0) {
        continue
    }
    
    # for logging
    Write-Output "$diskName has $freespace GB of free space"

    # for monday summary
    $diskSummaryArray += "$diskName` $freespace`GB"

    # if in test mode, semd test then stop
    if ($testMode) {
        Send-Notification -client "test" `
            -text "Test message from $server. The $server hard drive $diskName has $freespace GB of free space (on $env:computername / $ip) at the moment." `
            -title "Hard drive monitoring test" `
            -colour "green"
        Exit 0
    }

    # If < 5GB, send message
    if ($freespace -le 5) {
        Send-Slack  -mainMessage ":warning: Critical. The $server hard drive $diskName has $freespace GB of free space (on $env:computername / $ip) at the moment. :worried:" `
                    -colour "`#fb0e1f"
        Send-Notification -client $client `
                    -text "Critical. The $server hard drive $diskName has $freespace GB of free space (on $env:computername / $ip) at the moment." `
                    -title "Critical hard drive alert" `
                    -colour "red"
        Write-Output "Critical Alert sent to slack for $diskName has with $freespace GB (on $env:computername / $ip)"
    }
    # If < 10GB, send message if not already sent today, then record we've sent it
    ElseIf ($freespace -le 10 -and -not (Get-Message-Already-Sent)) {
        Send-Slack  -mainMessage "Caution. The $server hard drive $diskName has $freespace GB of free space at the moment. :thinking_face:" `
                    -colour "`#ff8c00"
        Send-Notification -client $client `
                    -text "Caution. The $server hard drive $diskName has $freespace GB of free space at the moment." `
                    -title "Caution hard drive alert" `
                    -colour "orange"
        Set-Message-Already-Sent
        Write-Output "Amber Alert sent to slack for $diskName has with $freespace GB and flag set to not send again today."
    }
}
# --- Checks ---
# Tell slack that we're online Monday 09:00 to 09:09 (as this script should run every 10 mins)
$min = Get-Date '09:00'
$max = Get-Date '09:09'
$now = Get-Date
[string]$diskSummary = $diskSummaryArray -join ", "
if ($min.TimeOfDay -le $now.TimeOfDay -and $max.TimeOfDay -ge $now.TimeOfDay -and $min.DayOfWeek -eq "Monday") {
    Send-Slack  -mainMessage "Morning everyone! Just to let you know I'm up and monitoring the $server hard drive free space. Free space: $diskSummary." `
                -colour "`#0efb1c"
    Send-Notification -client $client `
                -text "Morning everyone! Just to let you know I'm up and monitoring the $server hard drive free space. Free space: $diskSummary." `
                -title "Hard drive monitoring active" `
                -colour "green"
    Write-Output "Messaged slack a welcome online Monday message"
}

# Reset the "Message-Already-Sent" flag if we're on a new day (09:00 to 09:09)
if  ($min.TimeOfDay -le $now.TimeOfDay -and $max.TimeOfDay -ge $now.TimeOfDay) {
    Set-Message-Already-Sent -Flag ""
    Write-Output "Amber flag has been reset (to allow amber alerts again today)"
}

# Stop-Transcript