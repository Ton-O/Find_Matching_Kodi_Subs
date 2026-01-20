#!/bin/bash

global_DEBUG=
global_TRACE=

# --- Configuration ---
global_SRT_Patrh="/Volumes/Subtitles"                       # HARD coded path where subtitles are (and will be) stored
global_Video_Extensions="webm mkv flv vob ogv ogg rrc gifv mng mov avi qt wmv yuv rm asf amv mp4 m4p mpg mp2 mpeg mpe mpv m4v svi 3gp 3g2 mxf roq nsv flv f4v f4p f4a f4b mod"
global_API_Key="qo2wQs1PXwIHJsXvIiWXu1ZbVjaboPh6"          # The AP{I-kjey for Opensubtitles API}
global_User_Agent="MijnApp v1.0"                           # OpenSubtitles requires a User-Agent
global_Authentication_Done=""                                        # start with non-authenticated Opensubtitles
global_Season_Info=

global_Season=
global_Episode=
global_Result=
global_File_ID=
global_Auth_Token=
global_OpenSubtitles_Base_URL=
global_found_Release=

if [ "$1" == "TRACE" ]; then
    global_TRACE="TRUE"
    global_DEBUG="TRUE"
    shift
else
    if [ "$1" == "global_DEBUG" ]; then
        global_TRACE=
        global_DEBUG="TRUE"
        shift
    fi
fi
#    First declare all functions 
# Cleanup filename (replace  non-alnum by ?)
replace_non_alnum() {
    echo "$1" | sed 's/[^[:alnum:]]/?/g'
}

# Main function to find correct SRT, rename if needed and try to download if nothing found so far.
get_srt() {
    local tv_show="$1"
    local season="$2"
    local episode="$3"
    local target_name="$4"
    
    local target_srt="${global_SRT_Patrh}/${target_name}.srt"
    
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG get_srt"
    fi

    # Check if SRT already exists
    if [ -f "$target_srt" ]; then
        return 0 # SrtAlreadyExists
    fi
    
    # Find all SRT files containing the name of the TV  show
    # Use 'find' with case-insensitive search

    if [ -z "$Cached_SRT_files" ]; then
        if [ -n "$global_DEBUG" ]; then
            echo "<><><><> global_DEBUG Loading cache with all local SRT-files that match the showname"
        fi  
        Cached_SRT_files=$(find "$global_SRT_Patrh" -maxdepth 1 -iname "*${tv_show}*.srt")
    fi

    while IFS= read -r srt_file; do
        [ -z "$srt_file" ] && continue
        
        local srt_base=$(basename "$srt_file")
        local srt_info
        find_season_info "$srt_base"
        if [ -n "$global_TRACE" ]; then
          echo "<><><><> global_TRACE $global_Season_Info versus $season $episode $target_name"
        fi
        if [ -n "$global_Season_Info" ]; then
            read s_srt e_srt <<< "$global_Season_Info"
            if [ "$s_srt" == "$season" ] && [ "$e_srt" == "$episode" ]; then
                if [ -n "$global_TRACE" ]; then
                echo "<><><><> global_TRACE match, mv it"
                fi
                # Gevonden! Hernoemen
                mv "$srt_file" "$target_srt"
                return 4 # SrtMoved
            fi
        fi
    done <<< "$Cached_SRT_files"
    
    return 8 # SrtNotFound
}

function Main {
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG Main"
    fi
# --- Main Script ---
    # Use argument or fallback to a debug path
    local Filename
    local Ext
    local Filename_No_Ext
    local Stripped_Path
    local TV_Show
    local Cached_SRT_files
    local Output_Rec
    local Result
    local File_Path
    local Is_Video
    local Low_Extension

    Target_Dir="${1:-/Volumes/Media/Videos/Unforgotten/}"

    if [ ! -d "$Target_Dir" ]; then
        echo "Fout: Map niet gevonden: $Target_Dir"
        exit 1
    fi

    echo "Processing $Target_Dir"

    # Get the name of the TV SHow from th map name
    Stripped_Path="${Target_Dir%/}"
    TV_Show=$(basename "$Stripped_Path")
    #TV_SHOW_Masked=$(replace_non_alnum "$TV_Show")
    Cached_SRT_files=""                                                              # empty temporary cache of SRT-files as we have a new directory. 

    # find all files in directory
    find "$Target_Dir" -type f | while read -r File_Path; do
        Filename=$(basename "$File_Path")
        Ext="${Filename##*.}"
        Filename_No_Ext="${Filename%.*}"
        
        # Check for known video extensions
        Is_Video=false
        Lowcase_Extension=$(echo "$Ext" | tr '[:upper:]' '[:lower:]')
        
        case " $global_Video_Extensions " in
            *" $Lowcase_Extension "*)
                Is_Video=true
                ;;
        esac
        if [ "$Is_Video" = true ]; then
            find_season_info "$Filename"            
            if [ -n "$global_Season_Info" ]; then
                read global_Season global_Episode <<< "$global_Season_Info"
                Output_Rec="$TV_Show - Episode S${global_Season}E${global_Episode}"
                get_srt "$TV_Show" "$global_Season" "$global_Episode" "$Filename_No_Ext"
                Result=$?
                if [ "$Result" == "8" ]; then   # No subtitle found
                    if [ "$OpenSubtitlesAuth" == "true" ]; then 
                        MissingSubtitle "$TV_Show" "$global_Season" "$global_Episode" "$Filename_No_Ext"
                    Result=$?
                    else
                        Result=9
                    fi
                fi

                case $Result in
                    0) echo "$Output_Rec    Okay" ;;
                    1) echo "$Output_Rec    exact match downloaded; $OpenSubtitlesRemaining remaining downloads" ;;
                    2) echo "$Output_Rec    => Non-specific release group SRT (${global_found_Release})downloaded; $OpenSubtitlesRemaining remaining downloads" ;;
                    4) echo "$Output_Rec    ==> Srt renamed" ;;
                    8) echo "$Output_Rec    ========> Search OpenSubtitles for SRT but not found" ;;
                    9) echo "$Output_Rec    ========> No SRT found and cannot access OpenSubtitles (no OpenSubtitlesUser or OpenSubtitlesPasswd given)" ;;
                    10) echo "$Output_Rec    ========> SRT found, but download from OpenSubitles failed; retry this download later" ;;
                    16) echo "$Output_Rec    => No subtitle available already and KODI doesn't recognise path $TV_Show as a TV-show" ;;
                    *) echo "$Output_Rec    ==========> Error occurred" ;;
                esac
            else
                echo "Cannot establish Season Info for: $Filename"
            fi
        fi
    done
}

function MissingSubtitle {
    local TV_Show="$1" 
    local global_Season="$2" 
    local global_Episode="$3" 
    local Filename_No_Ext="$4"
    local Result

    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG MissingSubtitle"
    fi    
    TVShowName=$(echo "$TV_Show" |tr '[:upper:]' '[:lower:]')
    TVShowMaskedName=$(echo "$TVShowName" | sed 's/[^[:alnum:]]/+/g' )
 
    GetTVSHOWINF_From_KodiDB "$TVShowMaskedName" "$TVShowName"
    Result=$?
    if [ "$Result" != "0" ]; then
        return "$Result"
    fi
    DoOpenSubtitles "$TV_Show" "$TVShowMaskedName" "$global_Season" "$global_Episode" "$Filename_No_Ext"
}

function find_season_info() {
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG find_season_info"
    fi

    local filename=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    # Matcht s01e01, s1e1, s01x01, etc.
    global_Season_Info=""
    if [[ $filename =~ s([0-9]{1,2})[ex\ ]{1,2}([0-9]{1,2}) ]]; then
        # Normalise to 2 digits using printf
        printf -v global_Season_Info "%02d %02d" "$((10#${BASH_REMATCH[1]}))" "$((10#${BASH_REMATCH[2]}))"
    fi

}


function GetTVSHOWINF_From_KodiDB() {
    local TVShow="$2"
#    local DB_HOST="192.168.73.24"  # these DB-values are now placed in ~/.my.conf
#    local DB_USER="kodi"
#    local DB_PASS="kodi"
#    local DB_NAME="MyVideos131"
    local JSON_String
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG GetTVSHOWINF_From_KodiDB"
    fi  

    # IFS=$'\t' read -r SHOW_NAME SHOW_DESC  <<< $(mysql --defaults-file=~/.my.conf -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -N -s -e "SELECT c00, c10 FROM tvshow WHERE c00 = '${TVShow}' LIMIT 1;")
    IFS=$'\t' read -r SHOW_NAME SHOW_DESC  <<< $(mysql --defaults-file=~/.my.conf -N -s -e "SELECT c00, c10 FROM tvshow WHERE c00 = '${TVShow}' LIMIT 1;")
    if [ $? -ne 0 ]; then
        echo "Error connecting to the database."
        exit 4
    fi

    JSON_String=$(echo "$SHOW_DESC" | sed -e 's/<episodeguide>//g' -e 's/<\/episodeguide>//g')
    TVDB=$(echo "$JSON_String" | jq -r '.tvdb')
    IMDB=$(echo "$JSON_String" | jq -r '.imdb')
    TMDB=$(echo "$JSON_String" | jq -r '.tmdb')
    if [ -z "$TMDB" ]; then
        return 16
    fi
    return 0
}

function DoOpenSubtitles() {
    local TV_Show="$1" 
    local TVShowMaskedName="$2"
    local global_Season="$3" 
    local global_Episode="$4" 
    local Filename_No_Ext="$5"
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG DoOpenSubtitles"
    fi  

    SearchOpenSubtitles "$Filename_No_Ext" $global_Season $global_Episode "${TVShowMaskedName}"
    if [[ "$global_File_ID" != "-1" ]]; then  
        DownloadSubtitle  "${TV_Show%.*}" ${global_File_ID} "${Filename_No_Ext}" ""
        return $?
    else
        return 8
    fi
} 

function Get_AUTH_Token {
    local Result
    local Status
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG Get_AUTH_Token"
    fi  

    Result=$(curl -s -X POST "https://api.opensubtitles.com/api/v1/login" -H "Accept: application/json" -H "Api-Key: $global_API_Key" -H "Content-Type: application/json" -H "User-Agent: ${global_User_Agent}" -d '{"username": "'"$OpenSubtitlesUser"'", "password": "'"$OpenSubtitlesPasswd"'"}')
    Status=$(echo "$Result" | jq -r '.status'  2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "======================>   Unknown error when authenticating via OpenSubtitles API: $Result   <======================"
        exit 4
    fi
    if [ "$Status" != "200" ]; then
        echo "======================>   Error $Status when authenticating via OpenSubtitles API: $Result   <======================"
        exit 4
    fi

    global_OpenSubtitles_Base_URL=$(echo "$Result" | jq -r '.base_url')
    global_Auth_Token=$(echo "$Result" | jq -r '.token')
    if [[ -z "$global_Auth_Token" ]]; then
        global_Authentication_Done="" 
        return
    fi
    global_Authentication_Done=true
}

function SearchOpenSubtitles() {
    local Filename="$1"
    local global_Season="$2"
    local global_Episode="$3"
    local TVShow="$4"
    local OpenSubtitles_Release
    local Read_File_ID
    local Read_Filename
    local Read_Hearing_Impaired

    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG SearchOpenSubtitles"
    fi  

    local Matched=false
    local Found_Filename=""
    local Searching_Release

    global_File_ID=-1
    Searching_Release="${Filename##*[-_. ]}" 

    OpenSubtitles=$(curl -s -X GET -H "Api-Key:${global_API_Key}" -H "User-agent: ${global_User_Agent}" -H "Accept:application/json"  "https://api.opensubtitles.com/api/v1/subtitles?episode_number=${global_Episode}&languages=nl&machine_translated=include&parent_tmdb_id=${TMDB}&season_number=${global_Season}")

    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG SearchOpenSubtitles:" curl -s -X GET -H "Api-Key:${global_API_Key}" -H "User-agent: ${global_User_Agent}" -H "Accept:application/json"  "https://api.opensubtitles.com/api/v1/subtitles?episode_number=${global_Episode}&languages=nl&machine_translated=include&parent_tmdb_id=${TMDB}&season_number=${global_Season}"
        echo "<><><><> global_DEBUG SearchOpenSubtitles curl done: $OpenSubtitles"
    fi      

    while IFS="|" read -r Read_File_ID Read_Filename  Read_Hearing_Impaired; do
        OpenSubtitles_Release="${Read_Filename##*[-_.]}"
        if [[  "$Found_Filename" == "" ]]; then    #Grab the first subtitle, just in case no exact match on RELEASE-grpoup is found
            Found_Filename="$Read_Filename"
            global_File_ID="$Read_File_ID"
            global_found_Release=$OpenSubtitles_Release
            #echo "Grab the first subtitle; just in case: $Found_Filename $global_File_ID"
        fi
        if [ -n "$global_TRACE" ]; then
            echo "<><><><> global_TRACE SearchOpenSubtitles ${OpenSubtitles_Release,,}" = "${Searching_Release,,}" 
        fi
        if [ "${OpenSubtitles_Release,,}" = "${Searching_Release,,}" ]; then
            Found_Filename="$Read_Filename"
            global_File_ID="$Read_File_ID"
            Matched=true
            if [ "$Read_Hearing_Impaired" == "false" ]; then
                # We've got the release with no hearing_impaired; that's exactly what we want so stop the loop
                break
            fi
        fi
    done < <(echo "$OpenSubtitles" | jq -r '.data[]| "\(.attributes.files[].file_id)|\(.attributes.files[].file_name)|\(.attributes.hearing_impaired)"')
}

function DownloadSubtitle {
    #        
    local TV_Show="$1"
    local global_File_ID="$2"
    local Filename_No_Ext="$3"
    local Again=$4
    local Result

    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG DownloadSubtitle"
    fi      

     if [[ "$global_Authentication_Done" == "" ]]; then
         if [[ "$Again" != "" ]]; then
            echo "Could not get an Authentication token fromm Opensubtitles; aborting"
            exit 9
        fi 
        Get_AUTH_Token
        DownloadSubtitle  "${TV_Show%.*}" ${global_File_ID} "${Filename_No_Ext}" "TRUE"  # re-execute my self again, now hopefully with auth-token 
        return $?
    fi
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG DownloadSubtitle with token"
    fi      

    if [ -n "$global_DEBUG" ]; then                            # show what curl is executed
        echo curl -s -X POST \
            https://$global_OpenSubtitles_Base_URL/api/v1/download \
            -H 'Accept: application/json' \
            -H "Api-Key: $global_API_Key" \
            -H "Authorization: Bearer $global_Auth_Token" \
            -H 'Content-Type: application/json' \
            -H "User-Agent: $global_User_Agent" \
            -d "{\"file_id\": $global_File_ID}"
    fi

    Result=$(curl -s -X POST \
        https://$global_OpenSubtitles_Base_URL/api/v1/download \
        -H 'Accept: application/json' \
        -H "Api-Key: $global_API_Key" \
        -H "Authorization: Bearer $global_Auth_Token" \
        -H 'Content-Type: application/json' \
        -H "User-Agent: $global_User_Agent" \
        -d "{\"file_id\": $global_File_ID}")

    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG DownloadSubtitle curl download done; Result: $Result"
    fi      

    OpenSubtitlesMessage=$(echo "$Result" | jq -r '.message')
    OpenSubtitlesRemaining=$(echo "$Result" | jq -r '.remaining')
    SubtitleDownloadURL=$(echo "$Result" | jq -r '.link')
    SubtitleDownloadfile_name=$(echo "$Result" | jq -r '.file_name')

    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG DownloadSubtitle jq done"
    fi       

    if [[ -n "$SubtitleDownloadURL" ]]; then
        Result=$(wget -q "${SubtitleDownloadURL}" -O "${global_SRT_Patrh}/${Filename_No_Ext}.srt")
        RC=$?
        if [ -n "$global_DEBUG" ]; then
            echo "<><><><> global_DEBUG DownloadSubtitle wget done Result: $Result"
            echo "<><><><> DEBUGwget -q \"${SubtitleDownloadURL}\" -O \"${global_SRT_Patrh}/${Filename_No_Ext}.srt\""
        fi           
        if [ "$RC" == "0" ]; then
            $(touch "${global_SRT_Patrh}/${Filename_No_Ext}.srt")
            #echo "Downloaded $SubtitleDownloadfile_name and saved as ${global_SRT_Patrh}/${Filename_No_Ext}.srt"
            if [ "$Matched" == "true" ]; then
                return 1                            # signal Exact match was downloaded
            else
                return 2                            # signal subtitle was downloaded, but no exact match
            fi
        else
            return 10
        fi 
    else
        echo "******************** Could not get download-url from OpenSubtitles $Result"
        sleep 20s
        return 8
    fi
}
function CheckEnvironmentSetup {
    if [ -n "$global_DEBUG" ]; then
        echo "<><><><> global_DEBUG CheckEnvironmentSetup"
    fi  
    if [[ "$OpenSubtitlesUser" == ""  || "$OpenSubtitlesPasswd" == "" ]]; then
        echo "======================>   Missing Environment variables OpenSubtitlesUser and OpenSubtitlesPasswd   <======================"
        OpenSubtitlesAuth="false"
    else
        OpenSubtitlesAuth="true"
    fi

    if [[ ! -f "$HOME/.my.conf" ]]; then
        echo "Missing configuration for KODI-database connection; we will continue but we cannot get enough info for accessing OpenSubtitles"  
        OpenSubtitlesAuth="false"
    fi
} 

#    Now start calling these functions a.k.a. the program 

if [ -n "$global_DEBUG" ]; then
    echo "<><><><> global_DEBUG Starting PGM with $1"
fi  
CheckEnvironmentSetup
Main "$1"   # execute main loop

