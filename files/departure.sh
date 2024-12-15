#!/bin/bash
set -e

# Find stations: https://stoppested.entur.org/ user:guest pass:guest
# API IDE: https://api.entur.io/journey-planner/v2/ide/
# query MyQuery{stopPlace(id:"NSR:StopPlace:5823"){id name estimatedCalls(timeRange:72100 numberOfDepartures:2){expectedArrivalTime destinationDisplay{frontText}serviceJourney{journeyPattern{line{transportMode}}situations{description{language value}}}}}}

DEP_DATETIME=""
DEP_FRONTTEXT=""
DEP_SITUATIONS=""
FIGLET_TIME="figlet -w $(tput cols) -c -C utf8 -k -f mini"
FIGLET_TEXT="figlet -w $(tput cols) -c -C utf8 -S -f mini"
FIGLET="figlet -w $(tput cols) -c -C utf8 -S -f future"
STATION_COUNT=2
STATION_ID="NSR:StopPlace:5823"
UPDATED_JSON_FILE="$(mktemp --suffix -json)"
UPDATED_TIME_FILE="$(mktemp --suffix -time)"
UPDATE_FREQ_MIN=10

trap 'rm -f "$UPDATED_JSON_FILE" "$UPDATED_TIME_FILE"' INT TERM QUIT

function get_update() {
  curl -s https://api.entur.io/journey-planner/v3/graphql \
       -H 'Content-Type: application/json' \
       -H 'ET-Client-Name: heimsbakk.no-rasberrypi' \
       -d '{"query": "{stopPlace(id:\"'$STATION_ID'\"){id name estimatedCalls(timeRange:72100 numberOfDepartures:'$STATION_COUNT'){expectedDepartureTime destinationDisplay{frontText}serviceJourney{journeyPattern{line{transportMode}}situations{description{language value}}}}}}"}'
}

function get_departure_data() {
  local number json
  number="$1"
  json="$2"

  DEP_DATETIME=$(echo "$json" | jq -r ".data.stopPlace.estimatedCalls[$number] | .expectedDepartureTime")
  DEP_FRONTTEXT=$(echo "$json" | jq -r ".data.stopPlace.estimatedCalls[$number] | .destinationDisplay.frontText")
  DEP_SITUATIONS=$(echo "$json" | jq -r ".data.stopPlace.estimatedCalls[$number] | .situations[]?.description[]? |  select(.language == \"no\") | .value")
}

function get_datetime_diff() {
  local datetime
  datetime="$1"

  echo $(( $(date -d"$datetime" +%s) - $(date +%s) ))
}

function get_departure_departuretime() {
  local datetime sec
  datetime="$1"
  sec="$(get_datetime_diff "$datetime")"

  printf "%02d:%02d\n" $(( sec / 60 )) $(( sec % 60 ))
}

function get_departure_fronttext() {
  local fronttext
  fronttext="$1"

  [[ -z "$fronttext" ]] || printf "%s\n" "$fronttext"
}

function get_overview() {
  local updated_json updated_time cols now
  updated_json="$(cat "$UPDATED_JSON_FILE")"
  updated_time="$(cat "$UPDATED_TIME_FILE")"
  cols=$(($(tput cols) - 1))
  now=$(date +%s)

  # check if we need update
  if [[ $(( updated_time + (60 * UPDATE_FREQ_MIN) )) -lt $now ]]; then
    updated_json=""
  elif [[ -n "$updated_json" ]]; then
    get_departure_data 0 "$updated_json"
    if [[ $(get_datetime_diff "$DEP_DATETIME") -lt 0 ]]; then
      updated_json=""
    fi
  fi

  # update if no json in buffer
  if [[ -z "$updated_json" ]]; then
    get_update > "$UPDATED_JSON_FILE"
    date +%s > "$UPDATED_TIME_FILE"
  fi

  if [[ -n "$updated_json" ]]; then
    for (( i=0; i < STATION_COUNT; i++ )); do
      get_departure_data "$i" "$updated_json"
      get_departure_fronttext "$DEP_FRONTTEXT" | $FIGLET_TEXT -w "$cols"
      get_departure_departuretime "$DEP_DATETIME" | $FIGLET_TIME -w "$cols"
      [[ -z "$DEP_SITUATIONS" ]] || echo "$DEP_SITUATIONS" | tr -s '\n' ' ' | ( fold -sw "$cols" && echo )
      [[ -z "$DEP_SITUATIONS" ]] && echo --- | $FIGLET_TIME -w "$cols"
    done
  fi
}

function run() {
  local home ed el
  home=$(tput cup 0 0)        # move to row col
  ed=$(tput ed)               # clear to of screen
  el=$(tput el)               # clear to end of line
  printf '%s%s' "$home" "$ed"
  echo -n "$(tput setaf 7)"   # set white text
  echo -n "$(tput bold)"      # set bold text
  while true
  do
    local rows cols
    rows=$(( $(tput lines) - 1 ))
    cols=$(tput cols)
    get_overview | head -n $rows | while IFS= read -r line; do
      printf '%-*.*s%s\n' "$cols" "$cols" "$line" "$el"
    done
    printf '%s%s' "$ed" "$home"
    sleep 1
  done
}

run
