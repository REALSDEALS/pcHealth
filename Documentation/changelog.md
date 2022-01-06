# Changelog.md - pcHealth

## 06-01-2022

Updated the Project board on GitHub.
This commit is due to these additions, see it as a reminder for me...
Nothing special.

## 03-01-2022

After a small break we continue working on the script.
Thanks to a colleague of me, I have added the license key function to the script.

He provided the codeline and asked if I could implement it. 
So credits were credits due.

This function is in the new beta release.
later this week I will push a official release.

## 24-12-2021

Today we have reworked the visual representation of the script.
The way it displays text to the user and guides the user through the script was a bit harse, so we made it somewhat easier to read.

 - This includes the menu and function lines.

This could get another rework in the future, but for now this will do.

 - We could, in the future rework it again, to give the user the option(s) and visually 'gather' the input on the next line.

PowerShell script has been updated to output some standard features.
Not every function works yet, but most of them do now.

## 22-12-2021

Added the function to the code so the script closes itself when the user choses to use the reshut function.
Releases and other documentation files have been updated.

## 16-12-2021

A new folder has been created, this folder contains the PowerShell variant of the pcHealth.bat.
At this moment, the PowerShell script is unuseable.

Keep track of this changelog.md or releases.md if there is a stable release of this PowerShell build.

## 15-12-2021

Modified the code, added a new feature/command to the script.
It is now possible to run command 2, to display which GPU is in your system.

Taggs have been updated, new beta release has been pushed.

Updated the GPU command, to display CPU info too.

pcHealth.bat has been moved inside a folder called CMD.
It might be possible that there will be a PowerShell version of this script.

## 14-12-2021

Changed the main code, so it cleans after a command has been ran.
The script changes color.

GREEN in standby/menu, RED when code is active/script is running.

It's now possible to log off, restart and/or shutdown your PC/Laptop via the Script. 
New Full Release will be pushed.

## 10-12-2021

Added a function to display and read the system information from the command line.

Updated README.md, Changelog.md and releases.md

Updated release.md, it now displays on which version we are, what the full releases are and which the alpha/beta builds were.

## 09-12-2021

New function has been added, you can now open the GUI to check for Windows Updates.
In the future I want to add something that will force to check for updates and install them directly or give the user the choice to force them.

But this will be the placeholder for now.

README.md has been updated to explain what 'Number 5 does.'

Added 2 new functions, short ping en continues ping.
Updated the README.md again for the explanation of what it does.

## 08-12-2021

Updated the README.md
Updated releases.md
Updated this Changelog.md

New release has been pushed on GitHub.
Made an error in the release, going to re-release the script...

Decided after a lot of testing today that we are going to full release the .bat file.
The script works as it is now, more or other features maybe/will be added in the future.

Full release version: v1.0.0

## 07-12-2021

Added code to make the program aware if it is being run in Admin mode.
If it isn't it will prompt the user to do so.

Added a new function to the code.

- You can now get your Ninite through the terminal!

## 06-12-2021

Reformatted the code, to make it easier for other dev's to start working on it or to understand what it does.
Changed the color to Green.

Reworked the DISM code, so it doesn't try to display a log that is made with the SFC command.

## 03-12-2021

Changed some code to make it more streamlined.
Added some new menu's to navigate through.

Made it possible to open logs ect, this was already possible but I optimized the way it works.

Added a new file to the documentation folder; 'releases.md.'
This keeps track on the latest releases.

Also there has been a new release of this script.

- Alpha Release - v0.1.2-alpha

Oh ooh, made a typo, resolved it!

## 02-12-2021

Added the function to open the battery report via the script.
So people won't have to navigate to the file to check the script.

Tweaked so there is an extra 'space' behind the ENTER function.

Added a function to open the CBS.log that will be generated when there is a corruption detected.
User will get the option to open it or to skip it.

When a log has been generated, user will the option to re-open it via the 'main' menu.
Visual interface has been tweaked too.

## 01-12-2021

Added some new functions, overall updated the main code to function and display better.
Added the date and time after the license.

Wanted to add a 'release' function, but this one is held back, since it worked in the first test but broke in the test following the first...

Created an extra return menu, but all these menus have their own variable, so the changes are minimal on creating bugs/other problems.

## 29-11-2021

Update on the 'return to menu' issue/function.
Added a GOTO function to go back to the 'menu.'

Changed the color from yellow to 'Aqua.'
Made some changed to how the code works.

Added an exrta feature to scan and repair right after eachother without making it run again through the menu.

Made a small mistake, didn't added the 'number 5' as an option in the code, so users that aren't familiar with the program wouldn't know they could use the 'number 5' to exit the batch program.

## 23-11-2021

Updated the README.md to tell a user more about the repository and how to use the .bat file.

## 23-11-2021

Added a new function to the main code.
It is now possible to run a diagnostic to check your laptop it's battery state.

## 22-11-2021

I have taken a quick look at the code, to see what has to be changed.

## 22-11-2021

The main code has been created, this means that the batch file works.
It is able to react on a user it's input and follow through with a function.

## 21-11-2021

Project has been started.

Documentation folder has been created and this file to keep track of the changes.
Project board will be made and implemented through the website of GitHub.
