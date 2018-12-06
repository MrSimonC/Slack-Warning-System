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

$LogPath = Get-ScriptDirectory | Join-Path -ChildPath "log.txt"
Start-Transcript -path $LogPath -append
Write-Output "Script is running ok"

# global variables
$server = ""  # put an optional server name here for inclusion in slack alert text
$GlobalFlagPath = Get-ScriptDirectory | Join-Path -ChildPath "flag.txt"
$GlobalFlag = "messageAlreadySent"

# --- Slack WebHook ---
. (Get-ScriptDirectory | Join-Path -ChildPath SlackWebHooks.ps1)

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

function Send-Slack ([string]$mainMessage, [string]$webHook, [string]$colour
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
    -Uri $webHook | Out-Null
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
    # Write-Output "$diskName has $freespace GB of free space"

    # for monday summary
    $diskSummaryArray += "$diskName` $freespace`GB"

    # If < 5GB, send message
    if ($freespace -le 5) {
        Send-Slack  -mainMessage ":warning: Critical. The $server hard drive $diskName has $freespace GB of free space (on $env:computername / $ip) at the moment. :worried:" `
                    -webHook $SlackWebhook `
                    -colour "`#fb0e1f"
        Write-Output "Critical Alert sent to slack for $diskName has with $freespace GB (on $env:computername / $ip)"
    }
    # If < 10GB, send message if not already sent today, then record we've sent it
    ElseIf ($freespace -le 10 -and -not (Get-Message-Already-Sent)) {
        Send-Slack  -mainMessage "Caution. The $server hard drive $diskName has $freespace GB of free space at the moment. :thinking_face:" `
                    -webHook $SlackWebhook `
                    -colour "`#ff8c00"
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
                -webHook $SlackWebhook `
                -colour "`#0efb1c"
    Write-Output "Messaged slack a welcome online Monday message"
}

# Reset the "Message-Already-Sent" flag if we're on a new day (09:00 to 09:09)
if ($min.TimeOfDay -le $now.TimeOfDay -and $max.TimeOfDay -ge $now.TimeOfDay) {
    Set-Message-Already-Sent -Flag ""
    Write-Output "Amber flag has been reset (to allow amber alerts again today)"
}

Stop-Transcript