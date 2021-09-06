#!/bin/bash

function getURL()
{
    #
    # Ensure $link ends with "/api/"
    #
    if [[ -z $1 ]]
    then
        echo "You must specify a -l argument" 1>&2
        usage
    elif [[ $1 =~ /api$ ]]
    then
        link="$1/"
    elif ! [[ $1 =~ /api/$ ]]
    then
        if [[ $1 =~ /$ ]]
        then
            link="${1}api/"
        else
            link="$1/api/"
        fi
    else
        link="$1"
    fi
}
