# Slack-Warning-System

Warns a slack channel that a server is low on hard drive space.

## Background

Needing a free, customisable way of monitoring when a server's drive space gets low, I was challenged to come up with a quick script which would email out. Instead, I opted for a Slack incomming webhook (as sending messages this way is super easy and more private). I elected to write this in powershell for maintainability, and openness (even though I've never written Powershell before. _I don't care to again now_).

## Description

* Sends a once-a-day one-off "Amber" warning alert :warning: when any drive is under 10GB
* Will warn every time the script is run (every 10 mins) if any disk is under 5GB
* Between 9am and 9.09am
  * On a monday will announce it is online to the channel
  * Everyday will reset the "Amber" warning flag

## Setup

1. Create an incomming webhook in your team slack for a channel of your choice
2. Update `SlackWebHooks.ps1` with this webhook url
3. Install both .ps1 scripts on a server you want to monitor, in its own folder (e.g. `C:\Program Files\Slack Warning System`)
4. Ensure powershell script running is enabled:
    * Open a powershell prompt with Administrator privileges: `Set-ExecutionPolicy RemoteSigned`
5. Create a Windows Task Schedule to run every 10 minutes:
    * General:
      * Run with the highest privileges
    * Action: (_using example paths_)
      * Program/Script: `Powershell.exe`
      * Arguments: `-File "C:\Program Files\Slack Warning System\alert slack on low disk space.ps1"`
    * Start in:
      * `C:\Program Files\Slack Warning System`
      * **_Important: no quotes around the above path_**