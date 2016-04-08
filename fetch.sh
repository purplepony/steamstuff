#! /bin/bash

cookieFile="" # Fill this in!
groupID="" # Fill this in!
filePrefix="" # OPTIONAL: Specify prefix for saved logs. If empty, use group ID instead.
workingDir="/tmp/" # Location to save single-page files before concatenating
destination="" # Location to save final CSV list
download=0 # Specify whether to save raw HTML downloads of group history pages for debugging (default 0)
logging=0 # Specify whether to keep per-page CSV and debug logs (default 0)
logFile=$workingDir"grouplogger.log" # Log file name and location (if debugging is enabled)

if [ $logging -eq 1 ]; then echo "Starting script \"$0 $1 $2\"" >> $logFile; else logFile="/dev/null"; fi	
if [ -z ${groupID} ]; then groupID=$1;fi # User didn't fill in Group ID variable, check 2nd command-line parameter instead
if [ -z ${groupID} ]; then # 2nd parameter was not set either, fatal error
	echo -e "ERROR: No Steam group to search was specified.\n\nSyntax:  $0 \$SteamGroup \$CookieFile" >&2
	if [ $logging -eq 1 ]; then echo "ERROR: Steam group ID not specified." >> $logFile; fi
	exit 1 # Cannot proceed unless we know what group to search
fi
if [ -z ${cookieFile} ]; then cookieFile=$2;fi # User didn't fill in above variable for cookie file, try 3rd command-line parameter instead
if [ -z ${cookieFile} ]; then # 3rd parameter wasn't set either, fatal error
	echo -e "ERROR: Steam login cookie required to download history.\n\nSyntax:  $0 \$SteamGroup \$CookieFile" >&2
	if [ $logging -eq 1 ]; then echo "ERROR: Cookie file not specified, cannot download group history anonymously." >> $logFile; fi
	exit 2 # Cannot proceed without login cookie, exit with error
elif [ ! -e $cookieFile ]; then # File doesn't exist
	echo -e "ERROR: No cookie was found in file $cookieFile.\n\nSyntax:  $0 \$SteamGroup \$CookieFile" >&2
	if [ $logging -eq 1 ]; then echo "ERROR: Cookie file $cookieFile not found." >> $logFile; fi
	exit 2 # Cannot proceed without login cookie, exit with error
fi # No fatal errors, continuing.
if [ -z ${filePrefix} ]; then outputFiles=$groupID; else outputFiles=$filePrefix;fi # User didn't fill in above variable for cookie file, try 3rd command-line parameter instead
echo "Searching Steam group history for https://steamcommunity.com/groups/$groupID"
rm "$workingDir$outputFiles.csv" 2>/dev/null
touch "$workingDir$outputFiles.csv"
maxPage=$1 # Need to check how many pages of history there are first
index=0
until [ $? -ne 0 ]
do
	# Download and save each page as page_number.html then feed file into Python script
	let index=index+1 # Increment page counter (starting with page 1)
	echo -n "Fetching page $index... "
	wget --load-cookies $cookieFile --keep-session-cookies https://steamcommunity.com/groups/$groupID/history\?p=$index -O $workingDir$index.html -a $logFile
	echo -n "finding Steam IDs... "
	if [ $logging -eq 1 ]; then echo "Finding Steam IDs for page $index" >> $logFile; fi
	/usr/bin/python2.7 grouplog.py $workingDir$index.html > "$workingDir${outputFiles}_page$index.csv" 2>>$logFile
	if [ $? -ne 0 ]; then # Pyhton script will throw error when given empty page, assume this means last page of history
		if [ $index -gt 2 ]; then # Expected error after last page of history indicates end of history
			echo "reached end of history."
			if [ $logging -eq 1 ]; then echo -e "Error in Python script after successfully parsing 1 or more pages.\nAssumed end of group history." >> $logFile; fi
		else # Failed on first page, handle as error and display troubleshooting tips
			echo -e "\n*****\nERROR: No group history found for https://steamcommunity.com/groups/$groupID\nCheck that the group ID and ensure the cookie file contains a valid Steam\nlogin session for a profile enrolled in Steam group, then try again.\nAlso check that you have your cookie file set and are using correct syntax.\n\nSyntax:  $0 \$SteamGroup \$CookieFile" >&2
			if [ $logging -eq 1 ]; then echo -e "Python script failed on first page.\nNo group history found for https://steamcommunity.com/groups/$groupID\nExiting..." >> $logFile; fi
			rm $workingDir$index.html 2>>$logFile
			exit 3 # Nothing to save, exit with error
		fi
		if [ $download -eq 0 ]; then rm $workingDir$index.html 2>/dev/null; fi
		break
	else
		cat $workingDir${outputFiles}_page$index.log >> $destination$outputFiles.csv
		echo "saved to $workingDir${outputFiles}_page$index.log."
		if [ $download -eq 0 ]; then rm $workingDir$index.html 2>>$logFile; else echo "Saved raw HTML to $workingDir$index.html and results to $workingDir${outputFiles}_page$index.csv">>$logFile; fi
		if [ $logging -eq 1 ]; then echo -e "Appended results from page $index to $destination$outputFiles.csv"; fi
	fi
	if [ $logging -eq 1 ]; then echo "Python script exited with status 0" >> $logFile; fi
done
if [ $logging -eq 1 ]; then echo "Found `cut -d ';' -f 4 $destination$outputFiles.csv | sort -n | uniq | wc -l` Steam IDs across $((index-1)) pages and exited script without errors" >> $logFile; fi
echo "Combined group history (with `cut -d ';' -f 4 $destination$outputFiles.csv | sort -n | uniq | wc -l` unique users) saved to $outputFiles.csv"
