#!/bin/bash
set -e

# Find stations: https://stoppested.entur.org/
# API IDE: https://api.entur.io/journey-planner/v2/ide/

DATETIME=""
FIGLET="figlet -w 53 -c -C utf8  -k -f mini"
FROMTTEXT=""
NEED_UPDATE=0
STATION="NSR:StopPlace:5823"
TMP_FILE="/tmp/departure.tmp"
DEPARTURES_COUNT=2

function get_update() {
  curl -s https://api.entur.io/journey-planner/v2/graphql \
       -H 'Content-Type: application/json' \
       -H 'ET-Client-Name: heimsbakk.no-rasberrypi' \
       -d '{"query":"{stopPlace(id:\"'$STATION'\"){id name estimatedCalls(timeRange:72100 numberOfDepartures:'$DEPARTURES_COUNT' omitNonBoarding:true){expectedDepartureTime destinationDisplay{frontText}serviceJourney{journeyPattern{line{transportMode}}}situations{description{language value}}}}}"}' > "$TMP_FILE"
}

function get_departure_data() {
  local number=$1

  DATETIME=$(cat "$TMP_FILE" | jq -r ".data.stopPlace.estimatedCalls[$number] | .expectedDepartureTime")
  FRONTTEXT=$(cat "$TMP_FILE" | jq -r ".data.stopPlace.estimatedCalls[$number] | .destinationDisplay.frontText")
  SITUATIONS=$(cat "$TMP_FILE" | jq -r ".data.stopPlace.estimatedCalls[1] | .situations[]?.description[]? |  select(.language == \"no\") | .value")
}

function get_datetime_diff() {
  local datetime="$1"
  echo $(( $(date -d"$datetime" +%s) - $(date +%s) ))
}

function get_departure() {
  local datetime="$1"
  local fronttext="$2"
  local sec="$(get_datetime_diff "$datetime")"

  [[ -z "$fronttext" ]] || printf "%s\n" "$fronttext"
  printf "%02d:%02d\n" $(( sec / 60 )) $(( sec % 60 ))
}

function get_overview() {
  # Delete file if data is older than 15 minutes
  find "$TMP_FILE" -mmin +15 -delete

  # Do we have local data, and is it new enough
  if [[ -f "$TMP_FILE" ]]; then
    get_departure_data 0
    time_diff="$(get_datetime_diff "$DATETIME")"
    if [[ 0 -ge $time_diff ]]; then
      NEED_UPDATE=1
    fi
  fi

  # Update if DATETIME is not set by this point or NEED_UPDATE
  if [[ -z "$DATETIME" ]] || [[ $NEED_UPDATE -gt 0 ]]; then
    get_update
  fi

  for (( i=0; i < $DEPARTURES_COUNT; i++ )); do
    get_departure_data $i
    get_departure "$DATETIME" "$FRONTTEXT" | $FIGLET
    [[ -z "$SITUATIONS" ]] || echo $SITUATIONS | fold -sw $(tput cols)
    [[ -z "$SITUATIONS" ]] && echo --- | $FIGLET
  done
}

function run() {
  home=$(tput cup 0 0)        # move to row col
  ed=$(tput ed)               # clear to of screen
  el=$(tput el)               # clear to end of line
  printf '%s%s' "$home" "$ed"
  echo -n $(tput setaf 7)
  echo -n $(tput bold)
  while true
  do
    rows=$(( $(tput lines) - 1 ))
    cols=$(tput cols)
    current_row=1
    echo "$(get_overview)" | head -n $rows | while IFS= read -r line; do
      printf '%-*.*s%s\n' $cols $cols "$line" "$el"
    done
    printf '%s%s' "$ed" "$home"
    sleep 1
  done
}

run
