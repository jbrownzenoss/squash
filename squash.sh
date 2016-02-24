#!/bin/bash

if [ -z $1 ]; then
	SERVICE=resmgr
else
	SERVICE=$1
fi

if [ -z $2 ]; then
	OVER=30
else
	OVER=$2
fi

echo 
echo "SQUASH - RESMGR IMAGE"
echo
echo "USAGE: ./sqaush.sh [IMAGE] [LAYERS] "
echo 
echo "  **WARNING: This script will flatten the localhost:/.../${SERVICE} image, *ALL* services will be restarted!! "
echo 
echo "             Please ensure that you have valid backups before running!! "
echo 
read -p "Are you sure you want to continue? [y/N] " -n 1 -r

echo 
if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
    exit 1
fi

echo 
echo "- SQUASH LOG - START - " $(date +%Y-%m-%d\ %H:%M:%S) > squash.log

RESMGR="$(docker ps | grep ${SERVICE} | awk '{print $2}' | grep ${SERVICE} | head -1)"

if [ -z $RESMGR ] ; then
	echo "[x] ${SERVICE} is NOT running" | tee -a squash.log
	echo 
else
	echo "[-] Found ${SERVICE} running image - ${RESMGR}" | tee -a squash.log
	LAYERS="$(expr $(docker history $(docker ps | grep ${SERVICE} | awk '{print $2}' | head -1) | wc -l) '-' 1)"
	echo "[-] Found ${LAYERS} layer(s)" | tee -a squash.log
	
	if [ $LAYERS -lt $OVER ] ; then
		echo "[-] Layer count is already low, no need to squash" | tee -a squash.log
	else
		echo "[-] Preparing.." | tee -a squash.log
		docker rmi ${SERVICE}-flatimage-import >> squash.log 2>&1
		docker rmi ${SERVICE}-layered-backup >> squash.log 2>&1
		rm -f flat.tar >> squash.log 2>&1

		echo "[-] Exporting ${LAYERS} layers.." | tee -a squash.log
		docker export --output=flat.tar $(docker ps | grep ${RESMGR} | awk '{print $1}' | head -1) >> squash.log 2>&1
		SIZE="$(ls -hs flat.tar | awk '{print $1}')"
		echo "[-] Exported ${SIZE} flatimage" | tee -a squash.log

		echo "[-] Importing ${SIZE} flatimage.." | tee -a squash.log
		cat flat.tar | docker import - ${SERVICE}-flatimage-import:latest >> squash.log 2>&1
		echo "[-] Image Imported with $(expr $(docker history $(docker images | grep ${SERVICE}-flatimage-import | awk '{print $3}') | wc -l) '-' 1) layer(s)" | tee -a squash.log

		echo "[-] Backing up ${RESMGR}.." | tee -a squash.log
		docker tag ${RESMGR} ${SERVICE}-layered-backup >> squash.log 2>&1

        echo "[-] Stopping Zenoss.resmgr.." | tee -a squash.log
        serviced service stop Zenoss.resmgr >> squash.log 2>&1
        sleep 5m

        echo "[-] Updating tags.." | tee -a squash.log
        docker rmi -f ${RESMGR} >> squash.log 2>&1
        docker tag ${SERVICE}-flatimage-import ${RESMGR} >> squash.log 2>&1
        docker rmi ${SERVICE}-flatimage-import >> squash.log 2>&1

		echo "[-] Cleaning up.." | tee -a squash.log
		rm -f flat.tar >> squash.log 2>&1

        echo "[-] Syncing containers.." | tee -a squash.log
        serviced docker sync >> squash.log 2>&1

        echo "[-] Starting Zenoss.resmgr.." | tee -a squash.log
        serviced service start Zenoss.resmgr >> squash.log 2>&1
        sleep 1m

		docker images >> squash.log 2>&1

		echo "- SQUASH LOG - STOP - " $(date +%Y-%m-%d\ %H:%M:%S) >> squash.log
	fi
fi

exit
