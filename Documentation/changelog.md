# Changelog.md - pcHealth

## 24-01-2022 - @BigoStream

Added a small detail to let the user know in which menu he/she is.

## 22-12-2022 - @BigoStream

Got rid of the buggs from the new feature... Those nasty little things...

## 21-12-2022 - @BigoStream

Added the functionality to let user navigate to the repository to (mainly cause) fetch their own download and/or version. 
They will be redirected to the main page of pcHealth.

Added a feature to the main screen, users can choose to check for early releases.

## 30-11-2022 - @BigoStream 

Added new functions to the script:
- Disk Optimilisation through the script.
- Disk Cleaning through the script.
- Trace route (tracert) through the script.

Tweaked a small error in the nav-menu: didn't display the new features...

## 22-11-2022 - @BigoStream - Full Version Release 1.5.9

Changed some colors.

## 16-11-2022 - @BigoStream - Full Version Release 1.5.8

Changed some minor faults in the script. 
Some 'return' to menu functions were moving the user to the wrong 'sub-'menu.

## 04-10-2022 - @BigoStream

PowerShell script has seen some changes, some small feature updates. Nothing special yet.

## 08-08-2022

Script has gotten some small adjustments and some of the colours have been changed.

## 05-08-2022

Function has been tweaked, can be implemented in the main code now.

#### Credits again: 
- To learn more about bios-pw I would suggest taking a look at the main repository from @bacher09
- https://github.com/bacher09/pwgen-for-bios 

### 05-08-2022

Added a new feature to the script.

BIOS-PW has been intergrated, it will redirect the user to the website of BIOS-PW or redirect to the original repository were people can learn more about it and what it does.

It has been given the 16th function number in the Tools menu.

- To learn more about bios-pw I would suggest taking a look at the main repository from @bacher09
- https://github.com/bacher09/pwgen-for-bios 

### 04-08-2022 

Added templates for people to fill in, regarding to bugs/issues or requesting features.
GitHub was being very intrusive about it, and has been prompting it to me for weeks now.

So I have added them, they can be found under .github in the main directory from this repository.

## 04-08-2022 - Full Version Release 1.5.4

Since the issue regarding the PR have been fixed and seemed to be up-to-date and stable enough, I will be releasing 1.5.4, since it has nice features people have been requested.

Such as a way to return to the sub-menu, instead of going way back to the first (main) menu.
Besides that it is now possible to fetch updates from system programs.

### 04-08-2022

Looked at the PR from @BigoStream, wasn't working in the first case.
Seemed to be an issue with some of the callbacks the script made... 

Should be fixed now, this can be tested in beta version 1.5.3 at function '10' in TOOLS Menu.

### 01-08-2022

BigoStream: Added a update instance.
Function-key: 8

Resolved hard-crash, regarding to function 8.

Reworked the line of code, was workable in .batch.

### 29-07-2022

Made a small mistake...

I made a wrong direction in the code for the programs menu, I redirected the 'return to sub-menu' function back to 'DOWNLOADABLES' but this wasn't a menu. Changed it to the right menu: 'PROGRAMS.'

So it should be up and running now!

### 29-07-2022 

You are now able to return to the previous menu. 
You will be prompted with an option; returning to the previous (sub)-menu or returning to the (main)-menu.

## 26-07-2022 - Full Version Release 1.5.0

Version 1.5.0 will be available!

We have removed a lot of issues which where present in the latest official release (1.4.0).

Thanks for using the 'software'! 

pcHealth will probably evolve in a different kind of program/software. With a GUI and a local database for people in the workfield that find it handy ;)

At last, I want to thank everyone who has been using, or has used pcHealth! 
I got a lot of feedback and was able to improve the script because of that, many thanks again.

Special credits go to the following people:

CREDITS: Jaccosf, Stensel and other testers!

### 26-07-2022

Added a feature to restart the audio-drivers on the host machine. 
This will be in the test menu = '1' and at function = '10'.

Since it runs through a .PS extension it isn't able to return the user to the main menu... This is one of the many limitations of .batch... :(

For this feature I have to give credit to Stensel, he recommanded and made a huge contribution to this specific feature. Thanks!

### 20-07-2022 

Reviewed the script by myself, saw some minor inconviences... fixed that.
The changes that I made to the script regarding downloading of progams, is a succes!

### 20-07-2022

Changed some small visual issues, re-adjusted some strange formats of text.
Huge update to the codelines/commands that bring you to a download page - submenu: 'tools'.

Full version release will be near!

### 07-07-2022

Updated option 13 - license key.

It tells you automatically that you don't have to worry for a 'negative' callback from the script.
Besides that it tells you about a different option you could try!

Added a new script which allows you to grab the windows license key and gives you an possibility to save it to a text file on the desktop.

This script is an extension for if the pcHealth.bat (option 13) doesn't comeback with a license key.

+ Removed some typo's and made a change in the displaying color regarding to Option 13.

### 04-03-2022

Change in colours regarding to the script.
Added a return to the 'opening' menu in the Tools category.

## 18-02-2022 - Full Version Release 1.4.0

REWORK part 2, couldn't work in it in the past days, due to health issues.
In this update/push we have reworked some of the main aspects that we promised to change on our latest stream.

Removed some 'dead' lines of code, made them come back to life somewhere else in the script ;)

Updated the README.md since a lot didn't apply anymore, since the rework has made some impact on how the script presents itself.
A quick note on the PS (PowerShell) variant, that project will be finished and started on later this first Q of this year.

CREDITS: @Jaccosf

### 12-02-2022

Updated the script to display 2 menu's instead of a bunch of un-organized options.
This will keep it easier to read and more foolproof/noobfriendly.

### 02-02-2022 

Changed the download link from the HWinfo.
So when you run this line it will redirect you to the latest HWinfo installer.

### 06-01-2022 - 07-01-2022

Updated the Project board on GitHub.
This commit is due to these additions, see it as a reminder for me...
Nothing special.

I added a new menu inside the code. 
Function number 15 has been added, this function opens a small menu with a small handfull of usefull test programs to run on your system.

This will be updated and upgraded in the future.
There will be a code format update too, so things may change and be not 'that clunky' anymore.

Updated some text issues that were being displayed in the script.

### 03-01-2022

After a small break we continue working on the script.
Thanks to a colleague of me, I have added the license key function to the script.

He provided the codeline and asked if I could implement it. 
So credits were credits due.

This function is in the new beta release.
later this week I will push a official release.

### 24-12-2021

Today we have reworked the visual representation of the script.
The way it displays text to the user and guides the user through the script was a bit harse, so we made it somewhat easier to read.

 - This includes the menu and function lines.

This could get another rework in the future, but for now this will do.

 - We could, in the future rework it again, to give the user the option(s) and visually 'gather' the input on the next line.

PowerShell script has been updated to output some standard features.
Not every function works yet, but most of them do now.

### 22-12-2021

Added the function to the code so the script closes itself when the user choses to use the reshut function.
Releases and other documentation files have been updated.

### 16-12-2021

A new folder has been created, this folder contains the PowerShell variant of the pcHealth.bat.
At this moment, the PowerShell script is unuseable.

Keep track of this changelog.md or releases.md if there is a stable release of this PowerShell build.

### 15-12-2021

Modified the code, added a new feature/command to the script.
It is now possible to run command 2, to display which GPU is in your system.

Taggs have been updated, new beta release has been pushed.

Updated the GPU command, to display CPU info too.

pcHealth.bat has been moved inside a folder called CMD.
It might be possible that there will be a PowerShell version of this script.

## 14-12-2021 - Full Version Release 1.2.2 / 1.2.3 / 1.3.0

Changed the main code, so it cleans after a command has been ran.
The script changes color.

GREEN in standby/menu, RED when code is active/script is running.

It's now possible to log off, restart and/or shutdown your PC/Laptop via the Script. 
New Full Release will be pushed.

## 10-12-2021 - Full Version Release 1.2.0 

Added a function to display and read the system information from the command line.

Updated README.md, Changelog.md and releases.md

Updated release.md, it now displays on which version we are, what the full releases are and which the alpha/beta builds were.

### 09-12-2021

New function has been added, you can now open the GUI to check for Windows Updates.
In the future I want to add something that will force to check for updates and install them directly or give the user the choice to force them.

But this will be the placeholder for now.

README.md has been updated to explain what 'Number 5 does.'

Added 2 new functions, short ping en continues ping.
Updated the README.md again for the explanation of what it does.

## 08-12-2021 - Full Version Release 1.0.0

Updated the README.md
Updated releases.md
Updated this Changelog.md

New release has been pushed on GitHub.
Made an error in the release, going to re-release the script...

Decided after a lot of testing today that we are going to full release the .bat file.
The script works as it is now, more or other features maybe/will be added in the future.

Full release version: v1.0.0

### 07-12-2021

Added code to make the program aware if it is being run in Admin mode.
If it isn't it will prompt the user to do so.

Added a new function to the code.

- You can now get your Ninite through the terminal!

### 06-12-2021

Reformatted the code, to make it easier for other dev's to start working on it or to understand what it does.
Changed the color to Green.

Reworked the DISM code, so it doesn't try to display a log that is made with the SFC command.

### 03-12-2021

Changed some code to make it more streamlined.
Added some new menu's to navigate through.

Made it possible to open logs ect, this was already possible but I optimized the way it works.

Added a new file to the documentation folder; 'releases.md.'
This keeps track on the latest releases.

Also there has been a new release of this script.

- Alpha Release - v0.1.2-alpha

Oh ooh, made a typo, resolved it!

### 02-12-2021

Added the function to open the battery report via the script.
So people won't have to navigate to the file to check the script.

Tweaked so there is an extra 'space' behind the ENTER function.

Added a function to open the CBS.log that will be generated when there is a corruption detected.
User will get the option to open it or to skip it.

When a log has been generated, user will the option to re-open it via the 'main' menu.
Visual interface has been tweaked too.

### 01-12-2021

Added some new functions, overall updated the main code to function and display better.
Added the date and time after the license.

Wanted to add a 'release' function, but this one is held back, since it worked in the first test but broke in the test following the first...

Created an extra return menu, but all these menus have their own variable, so the changes are minimal on creating bugs/other problems.

### 29-11-2021

Update on the 'return to menu' issue/function.
Added a GOTO function to go back to the 'menu.'

Changed the color from yellow to 'Aqua.'
Made some changed to how the code works.

Added an exrta feature to scan and repair right after eachother without making it run again through the menu.

Made a small mistake, didn't added the 'number 5' as an option in the code, so users that aren't familiar with the program wouldn't know they could use the 'number 5' to exit the batch program.

### 23-11-2021

Updated the README.md to tell a user more about the repository and how to use the .bat file.

### 23-11-2021

Added a new function to the main code.
It is now possible to run a diagnostic to check your laptop it's battery state.

### 22-11-2021

I have taken a quick look at the code, to see what has to be changed.

### 22-11-2021

The main code has been created, this means that the batch file works.
It is able to react on a user it's input and follow through with a function.

### 21-11-2021

Project has been started.

Documentation folder has been created and this file to keep track of the changes.
Project board will be made and implemented through the website of GitHub.
