# Find_Matching_Kodi_Subs
Orchestrate subtitles collection for KODI 

## What's the functionality of this script?
This script is meant to gather and administer subtitles for TVShows in KODI.

## Why this script?
I'm watching a lot of TVShows via KODI and download subtitles for them (mainly from OpenSubtitles) to a single Subtitle directory. I download subtitles mostly up0front before watching the show. 
When an epsiode is started, KODI checks this subtitle directory to see if it has appropriate subtitles for that TVShow&Season*&Episode. 
It does this by looking fo a file that has the same filename as the epsiode, but an extension for subtitles; in my case ".srt". 
However, the filenames downloaded from OpenSubtitles (or whatever site you get subtitles from) mostly do not match the filename of the episodes, so I always need to rename the subtitle file manually to match the TVShow&Season&Episode. After way to many manula renames, I decided to automate this process. In fact, I took it a step further and added automatic download of substitles if not already available in the subdtitles directory.
And yes, I DO have addons in KODI to download files from OpenSubtitles automatically, which is working fine, but I want to have the subtitles available before I start watching. 

## Who can use it?
Everyone that has KODI, TVShows in separate directories with a consistent naming scheme and a separate subtitle folder where all subtitles for KODI are stored.

## Which functions does the script deliver?
* Using a directory containing a TVShow as argument, it locates all video-files (TV-Episodes, from now on I'll call them "video-file") in that directory and in sub directories. The directory name that is passed, has to be the same as the TVShow.
* For each Episode, it tries to identify the correct Season and Episode as numbers so it can try to gather the specific subtitle for thatb TVShow, Season and Epsiode.
* It then, using the directory name as "Target TVShow name", finds all files in the subtitle directory that start with the "Target TVShow name". Then it parses the SxxEyy within both the "video-file" as well as each subtitle filename. If found, it will rename the subtitle filename to exactly match the "video-file".
* If it cannot find a matching "video-file" andsubtitle file, it makes a connection to the KODI-MYSQL database to collect the parent_tmdb_id for the TV Show being processed.
* It then connects to the OpenSubtitles API (from now an I call OpenSubtitles "OS") and searches for this parent_tmdb_id, together with the Season And Episode identified from the "video-file" to see if it has one or more subtitle files for that combination. I deliberately use parent_tmdb_id as KODI identifies that ID excellently during its video-scraping AND the "OS" API can use that (together with Season and Epsiode) to find the subtitles specific for this TVShow&Season&Episode. (it even tries to find the subtitle matching the Release group of "vindeo-file".
* The result is compared with the Release group; if it finds one, it checks the "OS" "Hearing Impaired flag"; if not set, for me that means an excellent match; a subtitle for a different Release group or with Hearing Impaired is also a match for me, but lower priority.
* It then authenticates the user by a logon via the "OS" API then downloads the subtitle that was selected and places it in the subtitle download directory with the correct name.

## Okay, I want to use this script, what do I need?
The automatic download from OpenSubtitles site works only if you:
* have a KODI database setup in mysql (as the mysql SQL and client is used in this script); to connect to mysql, you need to know the following:
*   IP-address (or hostname) of the mysql-server
*   database-name (at the moment, MyVideos131)
*   Userid and password assigned to the connectin that KODI has with mysql (kodi and kodi most of the time).
*   The variables need to be placed in a .my.conf file (the script expects thje file to be in the home fol,der of the user (file with chmod 600).
* have registered as a user on Opensubtitles.com (or via Opensubtitles.org). 

* The first stages (renaming existing files) works always, provided you have the following  
* Have a naming structure for "video-files" like this <TV-Show> <SaaEbb (or SaaXbb) wher aa = Season and bb = Episode). Not required, but obviously handy is to end the "video-file" name with the release group.
Tip: Use a product like Sonarr, that will keep an eye on the TVShows you're interested in, adds them to a download manager and generates video-files with the correct naming structure fopr this script.
In Sonarr, Settings, Media Management, just use this as standard format:
__{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Release Group}__ 

## How do I use this script?
As it's a shell script (Bash, actually), you have to execute the script in some way. 
Normlly, I just go to the directory that I want subtitles to be searched for, then execute this: ash ./Find_Subtitles_For_KODI.sh $(pwd) This just passes the current directory as the first argument.
If you receive and error that you can not execute the script, please make sure the "x-privilege" is set to the file: (sudo) chmod ygo+x Find_Subtitles_For_KODI.sh

The easiest way is to execute the following command from a command-line of a Linux system:
* If you have no KODI mysql database or no OpenSubtitles credentiala: 
*   bash ./Find_Subtitles_For_KODI.sh < DEBUG | TRACE>  <directory containing TVShow name> (season and epsiodes may be placed in subdirectories, the script will traverse down into all subdirectories).

*   If you have a KODI mysql database and OpenSubtitles credentials, you need to have a ~/.my.conf with db-settings and 2 environment variables set.
*   OpenSubtitlesUser=JohnDoe OpenSubtitlesPasswd=JaneDoe bash ~/Documents/FindSubs\ V1.2.sh "$(pwd)" will provide credentials and start the script.
<DEBUG | TRACE> is optional and only specified while debugging. 

# Any guarantees on this script? 
The one who spends the money, is the one who decides on wrong or right;-)
Seriously, this is a script that I created for my own benefit, if others want to use it, that's fine. I do not give formal support or guaranty the proper working, but am willing to look into issues that are reported on this github. Please note: I'm working on this in my own spare time, so no expectations.   

