#!/usr/bin/env bash

WATCHED_DIR=${1-./}
PORT=${2-8080}

start () {
  R -e "shiny::runApp('$WATCHED_DIR', port = $PORT)" &
  PID=$!
  trap cleanup SIGINT 
}
cleanup() {
  kill $PID
  echo "killed"
}

start

inotifywait -mr $WATCHED_DIR --format '%e %f' \
  -e modify -e delete -e move -e create \
  | while read event file; do

  echo $event $file

  kill $PID
  start

done
