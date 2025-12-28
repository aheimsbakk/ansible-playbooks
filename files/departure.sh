#!/bin/bash

# ==============================================================================
#  Entur Real-Time Departure Board (Bash + Figlet)
# ==============================================================================
#
#  Description:
#  This script turns your terminal into a real-time public transport departure
#  board using the Entur API.
#
#  Features:
#  - Color Modes: Color (Default) vs No Color (-C)
#  - Conditional Formatting: Destination is bold only in Color mode.
#  - Real-time countdowns (HH:MM:SS or MM:SS)
#  - Conditional Service alerts ("Situations")
#  - Auto-centering (Horizontal & Vertical)
#  - Option to hide station header (-H)
#
#  Author: Arnulf Heimsbakk (w/Gemini)
#
# ==============================================================================

# --- Dependencies Check ---
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v figlet &> /dev/null; then
    echo "Error: Missing dependencies."
    echo "Please install: curl, jq, figlet"
    exit 1
fi

# --- Default Configuration ---
STATION_NAME="Bergkrystallen"
NUM_DEPARTURES=2
VERSION="0.20"
API_URL="https://api.entur.io/journey-planner/v3/graphql"
CLIENT_NAME="personal-bash-script"
FETCH_INTERVAL=60
TRANSPORT_MODES="bus, tram, metro, rail, water"
FONT_NAME="mini"      # Default font
SHOW_HEADER=true      # Default: Show header
USE_COLOR=true        # Default: Use color

# --- Function: Help ---
show_help() {
    echo "Displays a live, auto-centering countdown of upcoming public transport departures"
    echo "using data from the Entur API."
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s <name>    Set station name (default: Bergkrystallen)"
    echo "  -n <number>  Number of departures to display (default: 2)"
    echo "  -m <modes>   Transport modes (default: all)"
    echo "  -i <seconds> API fetch interval in seconds (default: 60)"
    echo "  -f <font>    Figlet font name (default: mini)"
    echo "  -C           Disable colors (No-color mode)"
    echo "  -H           Hide station header and spacing"
    echo "  -v           Show version"
    echo "  -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") -s 'Nationaltheatret'"
    echo "  $(basename "$0") -C -H"
}

# --- Argument Parsing ---
while getopts ":s:n:m:i:f:vCHh" opt; do
  case ${opt} in
    s) STATION_NAME="$OPTARG" ;;
    n)
      if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
        NUM_DEPARTURES="$OPTARG"
      else
        echo "Error: -n requires a valid number."
        exit 1
      fi
      ;;
    m) TRANSPORT_MODES="$OPTARG" ;;
    i)
      if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
        FETCH_INTERVAL="$OPTARG"
      else
        echo "Error: -i requires a valid number (seconds)."
        exit 1
      fi
      ;;
    f) FONT_NAME="$OPTARG" ;;
    H) SHOW_HEADER=false ;;
    C) USE_COLOR=false ;;
    v)
      echo "Version: $VERSION"
      exit 0
      ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# --- Color & Style Configuration ---
if [ "$USE_COLOR" = true ]; then
    COL_GREEN=$(tput setaf 2)
    COL_RED=$(tput setaf 1)
    DEST_BOLD=$(tput bold) # Destination is bold in color mode
else
    COL_GREEN=""
    COL_RED=""
    DEST_BOLD=""           # Destination is NOT bold in no-color mode
fi
COL_RESET=$(tput sgr0)


# --- State Variables ---
NEXT_FETCH_TIME=0
DEPARTURE_DATA=""
STOP_ID=""

# --- Robust Cleanup Trap ---
cleanup() {
    trap - SIGINT SIGTERM EXIT
    tput cnorm
    tput sgr0
    clear
    echo "Stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# --- Helper: Generate Figlet Text ---
get_figlet() {
    figlet -s -C utf8 -c -w "$TERM_WIDTH" -f "$FONT_NAME" -- "$1"
}

# --- Helper: Center Normal Text ---
get_centered_text() {
    local text="$1"
    local len=${#text}
    local pad=$(( (TERM_WIDTH - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s%s" "" "$text"
}

# --- Helper: Generate Header Line ---
get_header_line() {
    local plain_inner="=< $STATION_NAME >="
    local str_len=${#plain_inner}
    local remaining_width=$((TERM_WIDTH - str_len))

    local left_count=$((remaining_width / 2))
    [ "$left_count" -lt 0 ] && left_count=0

    local right_count=$((remaining_width - left_count))
    [ "$right_count" -lt 0 ] && right_count=0

    local left_dashes=""
    for ((i=0; i<left_count; i++)); do left_dashes+="-"; done

    local right_dashes=""
    for ((i=0; i<right_count; i++)); do right_dashes+="-"; done

    echo "${left_dashes}=< $(tput bold)$STATION_NAME$(tput sgr0) >=${right_dashes}"
}

# --- Function: Fetch Data ---
fetch_data() {
    if [ -z "$STOP_ID" ]; then
        STOP_ID=$(curl -s -H "ET-Client-Name: $CLIENT_NAME" \
            "https://api.entur.io/geocoder/v1/autocomplete?text=${STATION_NAME// /%20}&lang=no" \
            | jq -r '.features[0].properties.id')
    fi

    if [ -z "$STOP_ID" ] || [ "$STOP_ID" == "null" ]; then
        DEPARTURE_DATA=""
        return 1
    fi

    local QUERY='{
      stopPlace(id: "'"$STOP_ID"'") {
        estimatedCalls(numberOfDepartures: '"$NUM_DEPARTURES"', whiteListedModes: ['"$TRANSPORT_MODES"']) {
          expectedDepartureTime
          destinationDisplay {
            frontText
          }
          situations {
            description {
              value
              language
            }
          }
        }
      }
    }'

    local RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
        -H "ET-Client-Name: $CLIENT_NAME" \
        --data "$(jq -n --arg q "$QUERY" '{query: $q}')" \
        "$API_URL")

    DEPARTURE_DATA=$(echo "$RESPONSE" | jq -r '
        .data.stopPlace.estimatedCalls[] |
        (
            if (.situations | length) > 0 then
                (.situations[0].description[] | select(.language=="no" or .language=="nob") | .value)
            else
                "null"
            end
        ) as $sit |
        "\(.destinationDisplay.frontText)|\(.expectedDepartureTime)|\($sit)"'
    )
}

# --- Main Loop ---
tput civis # Hide cursor
clear

while true; do
    NOW_SEC=$(date +%s)

    if [ "$NOW_SEC" -ge "$NEXT_FETCH_TIME" ]; then
        fetch_data
        if [ $? -eq 1 ] && [ -z "$DEPARTURE_DATA" ]; then
             DEPARTURE_DATA="ERROR"
        fi
        NEXT_FETCH_TIME=$((NOW_SEC + FETCH_INTERVAL))
    fi

    TERM_WIDTH=$(tput cols)
    TERM_HEIGHT=$(tput lines)
    [ -z "$TERM_WIDTH" ] && TERM_WIDTH=80
    [ -z "$TERM_HEIGHT" ] && TERM_HEIGHT=24

    CONTENT_BUFFER=""

    # Conditional Header Generation
    if [ "$SHOW_HEADER" = true ]; then
        CONTENT_BUFFER+=$(get_header_line)
        CONTENT_BUFFER+=$'\n'
        CONTENT_BUFFER+=$'\n'
    fi

    if [ "$DEPARTURE_DATA" == "ERROR" ]; then
         CONTENT_BUFFER+=$(get_figlet "Station Not Found")
    elif [ -z "$DEPARTURE_DATA" ]; then
        CONTENT_BUFFER+=$(get_figlet "Loading...")
    else
        while IFS='|' read -r DESTINATION ISO_TIME SITUATION_TEXT; do
            [ -z "$DESTINATION" ] && continue

            # --- Determine Status & Color ---
            CURRENT_COLOR=""
            HAS_SITUATION=false

            if [ -n "$SITUATION_TEXT" ] && [ "$SITUATION_TEXT" != "null" ]; then
                HAS_SITUATION=true
                CURRENT_COLOR="$COL_RED"
            else
                CURRENT_COLOR="$COL_GREEN"
            fi

            # --- Time Calculation ---
            if date --version >/dev/null 2>&1; then
                 DEP_SEC=$(date -d "$ISO_TIME" +%s)
            else
                 DEP_SEC=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${ISO_TIME%.*}" +%s 2>/dev/null)
            fi

            if [ -n "$DEP_SEC" ]; then
                DIFF_SEC=$((DEP_SEC - NOW_SEC))

                if [ "$DIFF_SEC" -le 0 ]; then
                    TIME_STR="Now"
                else
                    HOURS=$((DIFF_SEC / 3600))
                    REM_SEC=$((DIFF_SEC % 3600))
                    MINUTES=$((REM_SEC / 60))
                    SECONDS=$((REM_SEC % 60))

                    if [ "$HOURS" -gt 0 ]; then
                        TIME_STR=$(printf "%02d:%02d:%02d" "$HOURS" "$MINUTES" "$SECONDS")
                    else
                        TIME_STR=$(printf "%02d:%02d" "$MINUTES" "$SECONDS")
                    fi
                fi

                # --- Layout Construction ---

                # 1. Destination
                # Applies Color AND Bold (if enabled via DEST_BOLD)
                CONTENT_BUFFER+="$CURRENT_COLOR"
                CONTENT_BUFFER+="$DEST_BOLD"
                CONTENT_BUFFER+=$(get_figlet "$DESTINATION")
                CONTENT_BUFFER+="$COL_RESET"
                CONTENT_BUFFER+=$'\n'

                # 2. Situation Text (Only if valid)
                if [ "$HAS_SITUATION" = true ]; then
                    CONTENT_BUFFER+=$(get_centered_text "$SITUATION_TEXT")
                    CONTENT_BUFFER+=$'\n'
                fi

                # 3. Time (Always Bold)
                CONTENT_BUFFER+=$(tput bold)
                CONTENT_BUFFER+=$(get_figlet "$TIME_STR")
                CONTENT_BUFFER+=$(tput sgr0)
                CONTENT_BUFFER+=$'\n'
            fi
        done <<< "$DEPARTURE_DATA"
    fi

    # --- Render Logic ---

    # Trim trailing newline for perfect centering
    CONTENT_BUFFER="${CONTENT_BUFFER%$'\n'}"

    # Calculate actual lines
    CONTENT_LINES=$(echo -e "$CONTENT_BUFFER" | wc -l)

    # Calculate Padding
    PAD_TOP=$(( (TERM_HEIGHT - CONTENT_LINES) / 2 ))
    if [ "$PAD_TOP" -lt 0 ]; then PAD_TOP=0; fi

    # Reset Cursor
    tput cup 0 0

    # Draw Top Padding
    for ((i=0; i<PAD_TOP; i++)); do
        tput el
        echo ""
    done

    # Draw Content
    echo "$CONTENT_BUFFER" | while IFS= read -r line; do
        printf "%s" "$line"
        tput el
        echo ""
    done

    # Clear Bottom
    tput ed

    sleep 1
done
