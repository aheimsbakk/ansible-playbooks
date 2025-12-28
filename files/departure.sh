#!/bin/bash

# ==============================================================================
#  Entur Real-Time Departure Board (Bash + Figlet)
# ==============================================================================
#
#  Description:
#  This script turns your terminal into a real-time public transport departure
#  board using the Entur API. It fetches departure data for a specified station,
#  displays the destination and a dynamic countdown timer, and renders the
#  output in centered ASCII art using 'figlet'.
#
#  Features:
#  - Real-time countdowns (HH:MM:SS or MM:SS)
#  - Auto-centering (Horizontal & Vertical)
#  - Configurable transport modes (Metro, Tram, Bus, etc.)
#  - Configurable Figlet font
#  - Artifact-free refreshing
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
VERSION="0.12"
API_URL="https://api.entur.io/journey-planner/v3/graphql"
CLIENT_NAME="personal-bash-script"
FETCH_INTERVAL=60
TRANSPORT_MODES="bus, tram, metro, rail, water"
FONT_NAME="mini" # Default font

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
    echo "               Available: bus, tram, metro, rail, water"
    echo "  -i <seconds> API fetch interval in seconds (default: 60)"
    echo "  -f <font>    Figlet font name (default: mini)"
    echo "  -v           Show version"
    echo "  -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") -s 'Nationaltheatret' -m 'train, metro'"
    echo "  $(basename "$0") -f 'slant' -n 1"
}

# --- Argument Parsing ---
while getopts ":s:n:m:i:f:vh" opt; do
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
    # Uses the configured FONT_NAME
    figlet -c -w "$TERM_WIDTH" -f "$FONT_NAME" -- "$1"
}

# --- Helper: Generate Header Line ---
get_header_line() {
    # We construct the text without escape codes first to calculate length correctly
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

    # Construct the final string with BOLD codes only around STATION_NAME
    # Pattern: [Dashes]=< [BOLD]Name[RESET] >=[Dashes]
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
        }
      }
    }'

    local RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
        -H "ET-Client-Name: $CLIENT_NAME" \
        --data "$(jq -n --arg q "$QUERY" '{query: $q}')" \
        "$API_URL")

    DEPARTURE_DATA=$(echo "$RESPONSE" | jq -r '
        .data.stopPlace.estimatedCalls[] |
        "\(.destinationDisplay.frontText)|\(.expectedDepartureTime)"')
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

    # Header
    CONTENT_BUFFER+=$(get_header_line)
    CONTENT_BUFFER+=$'\n'
    CONTENT_BUFFER+=$'\n'

    if [ "$DEPARTURE_DATA" == "ERROR" ]; then
         CONTENT_BUFFER+=$(get_figlet "Station Not Found")
    elif [ -z "$DEPARTURE_DATA" ]; then
        CONTENT_BUFFER+=$(get_figlet "Loading...")
    else
        while IFS='|' read -r DESTINATION ISO_TIME; do
            [ -z "$DESTINATION" ] && continue

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

                # --- Layout ---
                CONTENT_BUFFER+=$(get_figlet "$DESTINATION")
                CONTENT_BUFFER+=$'\n'

                # Time (BOLD)
                CONTENT_BUFFER+=$(tput bold)
                CONTENT_BUFFER+=$(get_figlet "$TIME_STR")
                CONTENT_BUFFER+=$(tput sgr0)
                CONTENT_BUFFER+=$'\n'
            fi
        done <<< "$DEPARTURE_DATA"
    fi

    # --- Render Logic ---

    CONTENT_LINES=$(echo "$CONTENT_BUFFER" | wc -l)

    PAD_TOP=$(( (TERM_HEIGHT - CONTENT_LINES) / 2 ))
    if [ "$PAD_TOP" -lt 0 ]; then PAD_TOP=0; fi

    tput cup 0 0

    for ((i=0; i<PAD_TOP; i++)); do
        tput el
        echo ""
    done

    echo "$CONTENT_BUFFER" | while IFS= read -r line; do
        printf "%s" "$line"
        tput el
        echo ""
    done

    tput ed

    sleep 1
done
