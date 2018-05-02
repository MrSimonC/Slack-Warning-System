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

* Create an incomming webhook in your team slack for a channel of your choice
* Update the script with this webhook url
* Install the script on a server you want to monitor, in its own folder
* Create a Windows Task Schedule to run every 10 minutes
  * Point the task to start in the folder containing the script (obmit the quotes in windows scheduler in the "Actions", "Start in (optional)" field)