# Events Addon (Windower 4)

A simple Windower addon by Voliathon that checks what Adventurer Campaigns are currently active in Final Fantasy XI and displays them in a small on-screen box.

## Where the data comes from
The addon pulls the campaign schedule directly from the [BG-Wiki Adventurer Campaigns page](https://www.bg-wiki.com/bg/Category:Adventurer_Campaigns) via their API. As long as BG-Wiki is up to date, the addon will be too. It parses the wikitext, checks the start and end dates against your local system time, and only displays the campaigns that are currently active.

## Installation
1. Download the addon and place the files in your `Windower4/addons/` folder. Make sure the folder is named `events`.
2. Load it in-game by typing `//lua l events`.

## Commands
You can use either `//events` or `//campaign` as the base command:

* `//events show` - Fetches the latest data from BG-Wiki and shows the GUI box.
* `//events hide` - Hides the GUI box.
* `//events export` - Saves the currently displayed campaign list to a text file (`export.txt`) inside the addon folder.
* `//events help` - Prints the command list in your chat log.