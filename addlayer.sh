#!/bin/bash

if [ -z $1 ]; then
        echo "ADDLAYER - Generate x layers for docker image "
        echo
        echo "USAGE: ./addlayer.sh [LAYERS] "
        echo
        exit
else
        echo
        echo ADDLAYER
        echo "[-] Adding ${1} Layers " | tee -a addlayer.log
        COUNTER=1
        while [  $COUNTER -le $1 ]; do
                echo "[-] Adding Layer ${COUNTER} "
                docker rm -f $(docker ps -a | grep LAYER-${COUNTER} | awk '{print $1}') >> addlayer.log 2>&1
                serviced service shell -s LAYER-${COUNTER} zope --generate-bash-completion >> addlayer.log 2>&1
                serviced snapshot commit LAYER-${COUNTER} >> addlayer.log 2>&1
                let COUNTER=COUNTER+1
        done
fi

