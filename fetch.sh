#! /bin/bash

# Config settings, change these variables as needed.
cookieFile="" # Fill this in if not using parameters from command-line.
groupID="" # Fill this in if not using parameters from command-line.
filePrefix="" # OPTIONAL: Specify prefix for saved logs. If empty, use group ID instead.
workingDir="/tmp/" # Location to save single-page files before concatenating
destination="" # Location to save final CSV list
download=0 # Specify whether to save raw HTML downloads of group history pages for debugging (default 0)
logging=0 # Specify whether to keep per-page CSV and debug logs (default 0)
logFile=$workingDir"grouplogger.log" # Log file name and location (if debugging is enabled)
python="$(which 'python2.7')" # Look for Python 2.7 binary
autojoin=0 # Use this if you want to join Steam groups automatically. Set 0 if you don't want this account to join any groups, or 1 if you want to automatically join groups for logging when possible.

# Some constants, only adjust if Steam's user interface changes and script stops working.
joinButtonDiv='<div class="grouppage_join_area">'
loginButtonDiv='<div class="mainmenu_contents_items">'
inviteDiv='<div class="grouppage_pending_invite_description">'
loginButton='Login'
privateText='Membership by invite only'
joinButton='Join Group'
inviteButton='Invite Friends'
errorSpan='<p class="sectionText">'
genericError='An error was encountered while processing your request'
notFoundMessage='No group could be retrieved for the given URL.'
disabledMessage='This group has been administratively disabled.'

# Basic syntax error checking
if [ $logging -eq 1 ]; then echo -e "`date`:\nStarting script \"$0 $1 $2\"" >> $logFile; else logFile="/dev/null"; fi	
if [ -z ${groupID} ]; then groupID=$1;fi # User didn't fill in Group ID variable, check 2nd command-line parameter instead
if [ -z ${groupID} ]; then # 2nd parameter was not set either, fatal error
	echo -e "ERROR: No Steam group to search was specified.\n\nSyntax:  $0 \$SteamGroup \$CookieFile" >&2
	if [ $logging -eq 1 ]; then echo "ERROR: Steam group ID not specified." >> $logFile; fi
	exit 1 # Cannot proceed unless we know what group to search
fi
groupURL="https://steamcommunity.com/groups/$groupID" # Another constant, once we're sure we have group ID set
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

# Download front page for Steam group then start searching through it. Check for issues that will prevent access.
wget --load-cookies $cookieFile --keep-session-cookies $groupURL -O $workingDir$groupID.html -a $logFile 2>>$logFile
if [ $(grep -A 2 "$loginButtonDiv" $workingDir$groupID.html | grep $loginButton | wc -l) -ne 0 ]; then
	echo -e "You are not logged into Steam. Has your session expired?\nCheck that the file $cookieFile has a valid session and try again" >&2
	echo -e "You are not logged into Steam. Has your session expired?\nCheck that the file $cookieFile has a valid session and try again" >> $logFile
	exit 3 # Cookie file exists, but doesn't contain a valid session. Cannot work anonymously.
elif [ $(grep -A 3 "$errorSpan" $workingDir$groupID.html | grep -A 2 "$genericError" | grep "$notFoundMessage" | wc -l) -ne 0 ]; then
	echo "The group $groupURL doesn't exist." >&2
	echo "The group $groupURL doesn't exist." >> $logFile
	exit 4 # HTTP 404: Steam group doesn't exist.
# Private group
elif [ $(grep -A 2 "$joinButtonDiv" $workingDir$groupID.html | grep "$privateText" | wc -l) -ne 0 ]; then
	echo "Group is set to private (invite only), unable to join or access history." >&2
	echo "Group is set to private (invite only), unable to join or access history." >> $logFile
	exit 5 # Group requires invitation, unable to join. History is inaccessible.
# Disabled 
elif [ $(grep -A 3 "$errorSpan" $workingDir$groupID.html | grep -A 2 "$genericError" | grep "$disabledMessage" | wc -l) -ne 0 ]; then
	echo "Group has been shut down by Valve. No history available." >&2
	echo "Group has been shut down by Valve. No history available." >> $logFile
	exit 6 # Group has been administratively disabled, history is unavailable.
# Not enrolled
elif [ $(grep -A 2 "$joinButtonDiv" $workingDir$groupID.html | grep "$joinButton" | wc -l) -ne 0 ]; then
if [ $autojoin -eq 1 ]; then
	echo "Joining Steam group $groupURL"
	wget --load-cookies $cookieFile --keep-session-cookies $groupURL -O /dev/null --post-data "sessionID=$(wget --load-cookies $cookieFile --keep-session-cookies $groupURL -O- -a $logFile 2>>$logFile | grep -A 2 join_group_form | grep sessionID | cut -d '"' -f 6)&action=join" -a $logFile
else
	echo -e "Not a member of the Steam group $groupID. Please join group and try again.\nTo automatically join Steam groups in the future, set autojoin=1 in script." >&2
	echo -e "Not a member of the Steam group $groupID. Please join group and try again.\nTo automatically join Steam groups in the future, set autojoin=1 in script." >> $logFile
	exit 7 # Not a member of group, and autojoin is disabled. Cannot check history anonymously.
fi
# Enrolled
elif [ $(grep -A 4 "$joinButtonDiv" $workingDir$groupID.html | grep "$inviteButton" | wc -l) -ne 0 ]; then
	echo "Already enrolled in group $groupID, joining not necessary." >>$logFile
# Invited (same as enrolled)
elif [ $(grep -A 2 "$inviteDiv" $workingDir$groupID.html | wc -l) -ne 0 ]; then
	grep -A 2 "$inviteDiv" $workingDir$groupID.html | sed -e 's/<[^>]*>//g' | sed -e 's/^[[:space:]]*//'
	grep -A 2 "$inviteDiv" $workingDir$groupID.html | sed -e 's/<[^>]*>//g' | sed -e 's/^[[:space:]]*//' >>$logFile
else # None of the above apply. This may happen if Steam's user interface changes, adjust fields accordingly.
	echo -e "WARNING: Unknown error occurred while validating group home page.\n$groupURL" >&2
	echo -e "WARNING: Unknown error occurred while validating group home page $groupURL" >> $logFile
	if [ $(grep -A 3 "$errorSpan" $workingDir$groupID.html | grep -A 2 "$genericError" | wc -l) -ne 0 ]; then
		echo -e "The raw error message we got was:\n-----" >&2
		echo -e "The raw error message we got was:\n-----" >> $logFile
		grep -A 3 "$errorSpan" $workingDir$groupID.html | grep -v "$errorSpan" | sed -e 's/<[^>]*>//g' | sed -e 's/^[[:space:]]*//' >&2
		grep -A 3 "$errorSpan" $workingDir$groupID.html | grep -v "$errorSpan" | sed -e 's/<[^>]*>//g' | sed -e 's/^[[:space:]]*//' >> $logFile
		echo "-----" >&2
	else
		echo "No error message was found (unknown state). Attempting to continue..." >&2
		echo "No error message was found. Attempting to continue..." >> $logFile
	fi
fi
if [ $download -eq 0 ]; then rm $workingDir$groupID.html 2>/dev/null; fi

echo "Searching Steam group history for $groupURL"
gid=$(wget $groupURL/memberslistxml/?xml=1 -a $logFile -O- 2>>$logFile | grep groupID64 | sed -ne '/<groupID64>/s#\s*<[^>]*>\s*##gp')
echo "Found ID64 https://steamcommunity.com/gid/$gid"
rm "$workingDir$outputFiles.csv" 2>>$logFile
echo "Group History for https://steamcommunity.com/gid/$gid with vanity URL $groupURL" > "$destination$outputFiles.csv" 2>>$logFile
index=0
until [ $? -ne 0 ]
do
	# Download and save each page as page_number.html then feed file into Python script
	let index=index+1 # Increment page counter (starting with page 1)
	echo -n "Fetching page $index... "
	wget --load-cookies $cookieFile --keep-session-cookies $groupURL/history\?p=$index -O $workingDir$index.html -a $logFile
	echo -n "finding Steam IDs... "
	if [ $logging -eq 1 ]; then echo "Finding Steam IDs for page $index" >> $logFile; fi
	eval $python grouplog.py $workingDir$index.html > "$workingDir${outputFiles}_page$index.csv" 2>>$logFile
	if [ $? -ne 0 ]; then # Pyhton script will throw error when given empty page, assume this means last page of history
		if [ $index -gt 2 ]; then # Expected error after last page of history indicates end of history
			echo "reached end of history."
			if [ $logging -eq 1 ]; then echo -e "Error in Python script after successfully parsing 1 or more pages.\nAssumed end of group history." >> $logFile; fi
		else # Failed on first page, handle as error and display troubleshooting tips
			echo -e "\n*****\nERROR: No group history found for $groupURL\nCheck that the group ID and ensure the cookie file contains a valid Steam\nlogin session for a profile enrolled in Steam group, then try again.\nAlso check that you have your cookie file set and are using correct syntax.\n\nSyntax:  $0 \$SteamGroup \$CookieFile" >&2
			if [ $logging -eq 1 ]; then echo -e "Python script failed on first page.\nNo group history found for $groupURL\nExiting..." >> $logFile; fi
			rm $workingDir$index.html 2>>$logFile
			exit 3 # Nothing to save, exit with error
		fi
		if [ $download -eq 0 ]; then rm $workingDir$index.html 2>/dev/null; fi
		break
	else
		cat $workingDir${outputFiles}_page$index.csv >> $destination$outputFiles.csv
		if [ $logging -eq 1 ]; then echo -e "Appended results from page $index to $destination$outputFiles.csv" >> $logFile; fi
		if [ $download -eq 0 ]; then rm $workingDir${outputFiles}_page$index.csv 2>>$logFile; echo "done."; else echo "saved to $workingDir${outputFiles}_page$index.csv."; fi
		if [ $download -eq 0 ]; then rm $workingDir$index.html 2>>$logFile; else echo "Saved raw HTML to $workingDir$index.html and results to $workingDir${outputFiles}_page$index.csv">>$logFile; fi
	fi
	if [ $logging -eq 1 ]; then echo "Python script exited with status 0" >> $logFile; fi
done
if [ $logging -eq 1 ]; then echo "Found `cut -d ';' -f 4 $destination$outputFiles.csv | sort -n | uniq | wc -l` Steam IDs across $((index-1)) pages and exited script without errors" >> $logFile; fi
echo "Combined group history ($(( index-1 )) pages with `cut -d ';' -f 4 $destination$outputFiles.csv | sort -n | uniq | wc -l` unique users) saved to $destination$outputFiles.csv"
