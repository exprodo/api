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

#
# Explain why wget failed, given its exit status.
#
# Note that when the server replies with HTTP 401 (Unauthorized), wget
# discards the body of the response, even with --content-on-error, so the
# server's own error message is lost. That is why we have to explain it here.
#
function describeWgetFailure()
{
    case $1 in
        4) echo "network failure: could not connect to the server. Check the -l URL";;
        5) echo "SSL verification failure: the server's certificate could not be verified";;
        6) echo "the server refused the session (HTTP 401 Unauthorized). Either the session has expired or been logged out, or it has not completed two factor authentication. Use login.sh to get a new session (with -t if your account uses 2FA)";;
        7) echo "protocol error talking to the server";;
        8) echo "the server returned an HTTP error. Run wget without --quiet to see the status code";;
        *) echo "wget failed with exit status $1";;
    esac
}
