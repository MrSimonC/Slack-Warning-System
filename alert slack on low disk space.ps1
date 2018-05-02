Set-StrictMode -Version Latest

# find out current working directory
function Get-ScriptDirectory
{
    Split-Path $script:MyInvocation.MyCommand.Path
}
# gobal variables
$GlobalFlagPath = Get-ScriptDirectory | Join-Path -ChildPath "flag.txt"
$GlobalFlag = "messageAlreadySent"
$SlackWebhook = "https://hooks.slack.com/services/<INSERT YOUR OWN WEBHOOK HERE>"

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

# check each disk for low space
foreach ($disk in Get-WmiObject Win32_LogicalDisk) {
    $diskName = $disk | Select-Object Name  | Select-Object -ExpandProperty "Name"
    $free = $disk | Select-Object FreeSpace
    $freespace = [Math]::Round($free.Freespace / 1GB)
    
    # escape any CD Drives
    if ($freespace -eq 0) {
        continue
    }
    
    # If < 5GB, send message
    if ($freespace -le 5) {
        Send-Slack  -mainMessage ":warning: Critical. The RPS hard drive $diskName has $freespace of GB free space at the moment. :worried:" `
                    -webHook $SlackWebhook `
                    -colour "`#fb0e1f"
    }
    # If < 10GB, send message if not already sent, then record we've sent it
    ElseIf ($freespace -le 40 -and -not (Get-Message-Already-Sent)) {
        Send-Slack  -mainMessage "Caution. The RPS hard drive $diskName has $freespace of GB free space at the moment. :thinking_face:" `
                    -webHook $SlackWebhook `
                    -colour "`#ff8c00"
        Set-Message-Already-Sent
    }
}

# --- Checks ---
# Tell slack that we're online Monday 09:00 to 09:09 (as this script should run every 10 mins)
$min = Get-Date '09:00'
$max = Get-Date '09:09'
$now = Get-Date
if ($min.TimeOfDay -le $now.TimeOfDay -and $max.TimeOfDay -ge $now.TimeOfDay -and $min.DayOfWeek -eq "Monday") {
    Send-Slack  -mainMessage "Morning everyone! Just to let you know I'm up and monitoring the RPS hard drive free space." `
                -webHook $SlackWebhook `
                -colour "`#0efb1c"
}

# Reset the "Message-Already-Sent" flag if we're on a new day (09:00 to 09:09)
if ($min.TimeOfDay -le $now.TimeOfDay -and $max.TimeOfDay -ge $now.TimeOfDay) {
    Set-Message-Already-Sent -Flag ""
}
