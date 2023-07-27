#!/bin/bash

nowstamp() {
       	echo $(TZ=GMT+3 date +"%Y-%m-%d %H:%M:%S %z" ) 
}


tolog() {
	tee -a $LOG
}

LIMIT_UPLOAD=10240
LIMIT_DOWNLOAD=10240
STOP=false
UPDATE_CRON=false
SIZE_ONLY="--size-only"

for param in "$@"; do
  case $param in
    --limit-upload=*)
      LIMIT_UPLOAD="${param#*=}"
      ;;
    --limit-download=*)
      LIMIT_DOWNLOAD="${param#*=}"
      ;;
    --stop-services)
      STOP=true
      ;;
		--update-cron)
			UPDATE_CRON=true
			;;
    --size-only-off)
    SIZE_ONLY=""
    ;;
  esac
done
