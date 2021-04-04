#!/bin/bash
set -e

# Find stations: https://stoppested.entur.org/
# API IDE: https://api.entur.io/journey-planner/v2/ide/

DEP_DATETIME=""
DEP_FRONTTEXT=""
DEP_SITUATIONS=""
FIGLET="figlet -w $(tput cols) -c -C utf8  -k -f mini"
STATION_COUNT=2
STATION_ID="NSR:StopPlace:5823"
UPDATED_JSON_FILE="$(mktemp --suffix -json)"
UPDATED_TIME_FILE="$(mktemp --suffix -time)"
UPDATE_FREQ_MIN=5

trap 'rm -f "$UPDATED_JSON_FILE" "$UPDATED_TIME_FILE"' INT TERM QUIT

function get_update() {
  curl -s https://api.entur.io/journey-planner/v2/graphql \
       -H 'Content-Type: application/json' \
       -H 'ET-Client-Name: heimsbakk.no-rasberrypi' \
       -d '{"query":"{stopPlace(id:\"'$STATION_ID'\"){id name estimatedCalls(timeRange:72100 numberOfDepartures:'$STATION_COUNT' omitNonBoarding:true){expectedDepartureTime destinationDisplay{frontText}serviceJourney{journeyPattern{line{transportMode}}}situations{description{language value}}}}}"}'
}

function get_departure_data() {
  local number json
  number="$1"
  json="$2"

  DEP_DATETIME=$(echo "$json" | jq -r ".data.stopPlace.estimatedCalls[$number] | .expectedDepartureTime")
  DEP_FRONTTEXT=$(echo "$json" | jq -r ".data.stopPlace.estimatedCalls[$number] | .destinationDisplay.frontText")
  DEP_SITUATIONS=$(echo "$json" | jq -r ".data.stopPlace.estimatedCalls[1] | .situations[]?.description[]? |  select(.language == \"no\") | .value")
}

function get_datetime_diff() {
  local datetime
  datetime="$1"

  echo $(( $(date -d"$datetime" +%s) - $(date +%s) ))
}

function get_departure() {
  local datetime fronttext sec
  datetime="$1"
  fronttext="$2"
  sec="$(get_datetime_diff "$datetime")"

  [[ -z "$fronttext" ]] || printf "%s\n" "$fronttext"
  printf "%02d:%02d\n" $(( sec / 60 )) $(( sec % 60 ))
}

function get_overview() {
  local updated_json updated_time
  updated_json="$(cat "$UPDATED_JSON_FILE")"
  updated_time="$(cat "$UPDATED_TIME_FILE")"

  # check if we need update
  if [[ $(( updated_time + (60 * UPDATE_FREQ_MIN) )) -lt $(date +%s) ]]; then
    updated_json=""
  fi

  # update if no json in buffer
  if [[ -z "$updated_json" ]]; then
    get_update > "$UPDATED_JSON_FILE"
    date +%s > "$UPDATED_TIME_FILE"
  fi

  if [[ -n "$updated_json" ]]; then
    for (( i=0; i < STATION_COUNT; i++ )); do
      get_departure_data "$i" "$updated_json"
      get_departure "$DEP_DATETIME" "$DEP_FRONTTEXT" | $FIGLET
      [[ -z "$DEP_SITUATIONS" ]] || echo "$DEP_SITUATIONS" | fold -sw "$(tput cols)"
      [[ -z "$DEP_SITUATIONS" ]] && echo --- | $FIGLET
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
