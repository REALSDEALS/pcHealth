# pcHealth

Check the health of your Windows installation and much more!

![GitHub](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License) ![GitHub Top Language](https://img.shields.io/github/languages/top/REALSDEALS/pcHealth?color=green&label=Batchfile) ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release) ![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Release) ![GitHub Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

## What is the main purpose of pcHealth?

The main purpose of pcHealth is to assist 'users' that are working in the IT business to run some simple things to check the system on defaults. Besides that you can download some simple programs (that are well known) to assist you in a deeper investigation of the system. This script is purely to enlighten the work in the workfield, exspecially for repetetive things like this.

## How to use?

First of all I want to thank you, for downloading and using this script!
It really means a lot to me!

If you have any tips/tricks or remarks? 
Feel free to contact me on discord: **REALSDEALS**.

**Sidenote**: since version 1.6 and onwards, the Powershell section has been removed from the script. To read more about this decision, please read the changelog.

### More information regarding on how to install and use it:

- Download this repository.
- Extract it to the desktop to be sure that it will run with full permissions.
- Open the `scripts` folder and open the CMD folder in there.
- Open the file in the CMD folder and read the rules/commands carefully.
- Enter in the number of the desired command that you want to run. (Number + ENTER)
- Patiently wait for the script to finish. Some menu-options may take some time to finish.
- You can chose, depending on the command, what you want to do next. (Open logs ect.)

### For users that are not that known about what everything may or may not do...

## Tools Menu:
The entries that you may enter in this menu will execute some standard line of code.
So keep in mind that the .exe (this script) needs to be in administrator mode, it will prompt you when you open the program.

You have my promise, that I won't do anything malicious to your pc.
But I can only keep that promise if you are sure to have downloaded pcHealth.bat from my repo: https://github.com/REALSDEALS/pcHealth 
Otherwise I can keep no promise to that statement.

1. Gather generic information about the system.
2. Show CPU, GPU and RAM information.
3. Run a scan for corrupt and/or missing files. (Windows ISO/DISM related)
4. When option 3. can't repair the corrupt/missing files, you can try this option. (DISM)
5. Option 3. and 4. combined. (Puts both commands behind eachother)
6. Generate a battery report. (To see how your laptop battery is doing)
7. Shortcut to Windows Update.
8. Open a menu regarding disk optimization, this is a standard Windows function.
9. Opens and starts a disk clean program, this is a standard Windows function.
10. Short ping test. (Do I have internet?)
11. Continues ping test. (Does my internet stop at certain times?)
12. Starts the function 'TRACERT' and traces how many hops your system has to make before establishing an connection with the host. (Google)
13. Fetches updates for system programs, updates them too if needed.
14. Fetches updates for HP software and hardware, by running the HPIA tool. This tool will only work on HPE devices, such as ProBooks, EliteBooks, ZBooks, etc. The source URL is hpia.hpcloud.hp.com. View full list of hardware supported by HPIA: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/imagepal/ref/platformList.html
14. Re-enables the drivers, it restarts the audio drivers. (Having issues with sound?)
15. Re-open the battery report. (Can't find my generated report anymore? Try opening it this way)
16. Re-open the CBS.log (DISM log, report from option 4.) 
17. Get your Ninite! (Standard program downloader/updater; Chrome, Edge, VLC and 7Zip)
18. Check your Windows License Key.
19. BIOS password recovery.
20. Shutdown, reboot and/or logout from the system.
21. Open the other menu, it's called 'Programs'.
22. Returning to the previous menu, main-menu.
23. Close the script.


## Programs menu:
The entries that you may put in here will redirect you to the download page of the program.
This is a combination of winget packages and direct download links, since not all programs are available in winget.

While I understand that some of you may have questions about this decision, my goal was to simplify the process for you. You’re welcome to review the source code at any time to see exactly how it works. Additionally, if you prefer to download your software manually, that option is always available.

1. Hardware Info - This program will check which hardware is in your PC.
2. HWMonitor - This program will check the temperature of your hardware.
3. ADW Cleaner - This program will scan for malicious software (adware, malware, spyware).
4. CrystalDiskInfo - This program will check information about your HDD/SDD (serial etc.)
5. CrystalDiskMark - This program will test your HDD/SDD on possible malfunctions.
6. Prime95 - This program will stress test your CPU. Useful for overclocking and performance tests.
7. Windows PowerToys - Makes configuration in- and around Windows a tad easier. Adds some new features to your Windows.
8. Open the other menu, it's called 'Tools'.
9. Return to the previous menu. 
10. Close the script.

## KeyGrabber
The key grabber script does what it says!

It grabs the license key (windows) that's on your pc, and gives you an option to save it to your desktop.

## Questions
If you still have questions, you can send me a message on Discord as mentioned above.
My username is: **REALSDEALS**.

There is also a possibility to e-mail me, if that's what you desire (check my GitHub profile for that).

## pcHealthPlus
pcHealthPlus is my other repository, where I plan to gradually migrate the technology currently implemented here. My goal is to transition to PowerShell 7.5, as Microsoft is set to drop support for batch (.bat/.cmd) files in upcoming Windows releases.

Link to pcHealthPlus: [REALSDEALS/pcHealthPlus](https://github.com/REALSDEALS/pcHealthPlus)

## Win_Scan
~~Win_Scan is my other repository, but the functionality provided by Win_Scan has been implemented here...~~
~~The functionality is now fully integrated into this script. The old repository still exists, but it is deprecated.~~

~~Link to Win_Scan: [REALSDEALS/Win_Scan](https://github.com/REALSDEALS/Win_Scan)~~
