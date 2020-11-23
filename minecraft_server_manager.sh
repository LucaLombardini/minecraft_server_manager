#!/bin/bash

# 1 - INTERNAL VARIABLES SECTION
SERVER_DIR="minecraft_server"
BCKP_DIR="world_backup"

SERVER_FILENAME="server"
WORLD_DIR="world"

MANIFEST_URL="https://launchermeta.mojang.com/mc/game/version_manifest.json"

LOCAL_VERS=""
MAX_ARG_NO=1
STATUS=0

BCKP_HISTORY=5
FORCE_UPDATE="0"
# END - 1


# 2 - UTILITIES SECTION
strindex() {
	x="${1%%$2*}"
	[[ "$x" == "$1" ]] && echo -1 || echo "${#x}"
}

delim() {
	x="${1%$2*}"
	[[ "$x" == "$1" ]] && echo -1 || echo "${#x}"
}
# END - 2


# 3 - FUNCTIONALITIES SECTION
# 3_1 -INTRO & INFO
function intro {
	echo "################################################################################"
	echo -e "#  \e[1mMinecraft Server Manager\e[0m"
	echo "#  dev by: Luca Lombardini"
	echo "#  version: 0.1.4"
	echo "#  released: 23/09/2020"
	echo "################################################################################"
}
# END - 3_1


# 3_2 - CHECK INPUT ARGUMENTS [ DA RISTRUTTURARE ]
function argumentsChecker {
	if [ $1 -gt $MAX_ARG_NO ]; then
		echo -e "\e[33m[$(date +%T)] [script/NOTE]: too much argument passed thus ignoring the exceeding ones\e[0m"
	fi
}
# END - 3_2


# 3_3 - CHECK BOTH SERVER AND BACKUP DIRECTORY
function directoryChecker {
	# check if the server directory exist
	if [ -d $SERVER_DIR ]; then
		# check if the world backup directory exists, otherwise try create it
		if [ ! -d "$SERVER_DIR/$BCKP_DIR" ]; then
			mkdir "$SERVER_DIR/$BCKP_DIR"
			if [ -d "$SERVER_DIR/$BCKP_DIR" ]; then
				echo "[$(date +%T)] [script/INFO]: $SERVER_DIR/$BCKP_DIR backup directory has been created"
			else
				echo -e "\e[31m[$(date +%T)] [script/ERROR]: $SERVER_DIR/$BCKP_DIR backup directory cant be created\e[0m"
				exit -1
			fi
		fi
	else
		echo -e "\e[31m[$(date +%T)][script/ERROR]: $SERVER_DIR no such directory found\e[0m\n"
		exit -1
	fi
}
# END 3_3


# CHECK SERVER EXISTANCE
function jarServerChecker {
	# check server existence
	if [ ! -e $SERVER_FILENAME.jar ]; then
		echo -e "\e[31m[$(date +%T)] [script/ERROR]: $SERVER_FILENAME.jar file not found\e[0m"
		exit -1
	fi	
}


# LOCAL VERSION RETRIEVER [ TESTED ]
function localVersionRetriever {
	echo "[$(date +%T)] [script/INFO]: Retrieving local server version"
	LOCAL_SHA1=$(sha1sum "$SERVER_FILENAME.jar" | cut -d ' ' -f1)
	VERSION_MANIFEST=$(curl -s "$MANIFEST_URL")
	FLAG_FOUND=0
	for (( i = 0; FLAG_FOUND == 0; i++ )); do
		PACKAGE_URL=$(jq -r ".versions[$i].url" <<< "$VERSION_MANIFEST")
		if [[ "$PACKAGE_URL" == "null" ]]; then
			echo "[$(date +%T)] [script/WARNING]: Server version not found"
			break
		else
			SHA1_REF=$(curl -s "$PACKAGE_URL" | jq -r ".downloads.server.sha1")
			if [[ "$LOCAL_SHA1" == "$SHA1_REF" ]]; then
				FLAG_FOUND=1
				LOCAL_VERS=$(jq -r ".versions[$i].id" <<< "$VERSION_MANIFEST")
				echo "[$(date +%T)] [script/INFO]: Found server version: $LOCAL_VERS"
			fi
		fi
	done
}



# SERVER UPDATER
function serverUpdater {
	proceed=''
	if [[ $# > "0" ]]; then
		if [[ "$1" =~ ^[0-9]+.[0-9]+.[0-9]+$ ]]; then
			TARGET_VERS="$1"
		else
			echo -e "\e[31m[$(date +%T)] [script/ERROR]: Invalid version format\e[0m"
			exit
		fi
	else
		echo "[$(date +%T)] [script/INFO]: Retrieving latest server version"
		MANIFEST_DATA=$(curl -s "$MANIFEST_URL")
		LATEST_VERS=$(jq -r '.latest.release' <<< "$MANIFEST_DATA")
		if [[ "$LOCAL_VERS" < "$LATEST_VERS" ]]; then
			echo "[$(date +%T)] [script/INFO]: A new version has been found:"
			echo -e "\t\t\t\tCurrent version: $CURRENT_VERS"
			echo -e "\t\t\t\tLatest version: $LATEST_VERS"
		TARGET_VERS="$LATEST_VERS"
		else
			echo "[$(date +%T)] [script/INFO]: The server is already up to date"
		fi
	fi
	
	PACKAGE_URL=$(jq -r --arg TARGET_VERS $TARGET_VERS '.versions | .[] | select(.id==$TARGET_VERS) | .url' <<< "$MANIFEST_DATA")
	if [ -z "$PACKAGE_URL" ]; then
		echo "[$(date +%T)] [script/WARNING]: This server version does not exist. Check if is correct"
	elif [[ "$FORCE_UPDATE" = "0" ]]; then
		read -p 'Would you like to download it now? This will overwrite the previous file![y/N] ' proceed
	else
		proceed="y"
	fi
	
	if [[ "$proceed" = "y" || "$proceed" = "Y" ]]; then
		echo "[$(date +%T)] [script/INFO]: Downloading the server jar file"
		JAR_URL=$(curl -s $PACKAGE_URL | jq -r ".downloads.server.url")
		#mv "$SERVER_FILENAME.jar" "$SERVER_FILENAME.jar.old"
		wget --output-document="$SERVER_FILENAME.jar.tmp" -q $JAR_URL
		if [ ! -e "$SERVER_FILENAME.jar" ]; then
			echo -e "\e[31m[$(date +%T)] [script/ERROR]: Server jar file cannot be downloaded\e[0m"
			#mv "$SERVER_FILENAME.jar" "$SERVER_FILENAME.jar.old"
		else
			LOCAL_SHA1=$(sha1sum "$SERVER_FILENAME.jar.tmp" | cut -d ' ' -f1)
			SHA1_REF=$(curl -s "$PACKAGE_URL" | jq -r ".downloads.server.sha1")
			if [[ "$LOCAL_SHA1" == "$SHA1_REF" ]]; then
				echo "[$(date +%T)] [script/INFO]: Server file is integer"
				rm -rf "$SERVER_FILENAME.jar"
				mv "$SERVER_FILENAME.jar.tmp" "$SERVER_FILENAME.jar"
			else
				echo -e "\e[31m[$(date +%T)] [script/ERROR]: SHA1 checksum does not match\e[0m"
				proceed='n'
				read -p 'Would you like to keep the file even if is not integer?[y/N] ' proceed
				if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
					rm -rf "$SERVER_FILENAME.jar.tmp"
				fi
			fi
		fi
		echo "[$(date +%T)] [script/INFO]: Done"
	fi
}


# SERVER STARTER [ TESTED ]
function serverStarter {
	echo -e "[$(date +%T)] [script/INFO]: Starting the $SERVER_VERSION server...\e[0m"
	java -Xmx3072M -Xms1024M -jar "$SERVER_FILENAME.jar" nogui
	if (( $? == 0 )); then
		echo -e "\e[1m[$(date +%T)] [script/INFO]: Server stopped\e[0m"
	else
		echo -e "\e[33m[$(date +%T)] [script/WARNING]: anomal server stop\e[0m"
		exit -1
	fi
} 


# CREATE THE WORLD BACKUP (format world_name-yyyy-mm-dd-hh-mm-ss.zip) [ TESTED ]
function worldBackUpper {
	local date_str
	local time_str
	date_str=$(date +%F)
	time_str=$(date +%T)
	echo -e "[$(date +%T)] [script/INFO]: creating the server's world backup..."
	zip -qrT "$BCKP_DIR/$WORLD_DIR-$date_str-$time_str" $WORLD_DIR
	if (( $? == 0 )); then
		echo "[$(date +%T)] [script/INFO]: Server's world successfully backed up"
	else
		echo -e "\e[33m[$(date +%T)] [script/ERROR]: Server world cant be backed up"
	fi
}


# REMOVE THE OLDEST BACKUPS EXCEPT FOR THE SPECIFIED LATEST ONES [ TESTED ]
function removeOldestBackUps {
	local BCKP_CNTR=1
	for bckp in $(ls "$BCKP_DIR" | grep "$WORLD_DIR.\+\.zip" | sort "-r")
	do
		if [ $BCKP_CNTR -gt $BCKP_HISTORY ]; then
			rm -rf "$BCKP_DIR/$bckp"
		fi
		BCKP_CNTR=$(( BCKP_CNTR + 1 ))
	done
}


# RESTORES A BACKUP [ TESTED ]
function backUpRestorer {
	local proceed=''
	select bckp in $(ls "$BCKP_DIR" | grep "$WORLD_DIR.\+\.zip" | sort "-r"); do
		if [ ! -z "$bckp" ]; then
			read -p 'This action will overwrite the current world data! Would you like to proceed anyways?[y/N] ' proceed
			if [[ "$proceed" = "y" || "$proceed" = "Y" ]]; then
				echo "[$(date +%T)] [script/INFO]: Restoring the server world..."
				unzip -qqto "$BCKP_DIR/$bckp"
				echo "[$(date +%T)] [script/INFO]: Done!"
			fi
		fi
		break
	done
}

function print_usage {
	echo "Usage:"
	echo -e "\t$0 --start [or empty]: start the server, creates the backup after closing it and remove the oldest"
	echo -e "\t$0 --restore [or -r]: restores the server to a previous state by choosing one from the backup folder. \e[4mNote\e[0m: It overwrites the current one !!!"
	echo -e "\t$0 --settings-save: saves the settings"
	echo -e "\t$0 --settings-restore: restores the settings. \e[4mNote\e[0m: It overwrites the current one !!!"
}


intro
argumentsChecker $#
directoryChecker
cd minecraft_server

case $1 in

	"" | "--start")
		jarServerChecker || exit -1
		serverStarter
		if (( $? == 0 )); then
			worldBackUpper
			removeOldestBackUps
		fi
	;;

	"--restore" | "-r")
		backUpRestorer
	;;

	"--update" | "-u")
		localVersionRetriever
		serverUpdater $2
	;;
	"--debug-local-version")
		localVersionRetriever
	;;
	"--debug-server-start")
		serverStarter
	;;
	*)
		print_usage
	;;		
esac


#	if [ -e "$VERSION_FILE" -a -s "$VERSION_FILE" ]; then
#		CURRENT_VERS=$(jq -r '.latest.release' < version_manifest.json)
#		echo "[$(date +%T)] [script/INFO]: Version file has been found, version has been loaded: $CURRENT_VERS"
#	else
#		CURRENT_VERS=$(ls | grep jar)
#		START_DELIM_POS=$(( $(strindex $CURRENT_VERS .) + 1 ))
#		END_DELIM_POS=$(( $(delim $CURRENT_VERS .) - $(strindex $CURRENT_VERS .) - 1))
#		CURRENT_VERS="${CURRENT_VERS:$START_DELIM_POS:$END_DELIM_POS}"
#		echo "[$(date +%T)] [script/INFO]: Version file not found, version retrieved from jar filename, hope no one changed it"
#	fi


	#ZIP_DESTIN_STRING="$JAR_BCKP/$CURRENT_VERS"
	#ZIP_SOURCE_STRING="$SERVER_DIR.$CURRENT_VERS.jar"
#echo "[$(date +%T)] [script/INFO]: Backing up the server jar file and its info..."
			#if [ -e "$VERSION_FILE" ]; then
			#	ZIP_SOURCE_STRING="$ZIP_SOURCE_STRING $VERSION_FILE"
			#fi
			#zip -qrT  "$ZIP_DESTIN_STRING" "$ZIP_SOURCE_STRING"
			#if (( $? == 0 )); then
			#	echo "[$(date +%T)] [script/INFO]: Server jar file backed up"
			#else
			#	echo -e "\e[33m[$(date +%T)] [script/ERROR]: Server jar file cant be backed up"
			#fi
			# DOWNLOAD VERSION FILE
			#echo "[$(date +%T)] [script/INFO]: Downloading the server jar version manifest"
			#curl -s "$MANIFEST_URL" > $VERSION_FILE
			#echo "[$(date +%T)] [script/INFO]: Done"
			# DOWNLOAD JAR FILE
