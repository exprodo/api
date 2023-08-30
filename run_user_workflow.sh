#!/bin/bash

session_id=
link=
workflow=0
biskitPK=0
biskitType=
menuItem=0
label=

source `dirname $0`/lib.sh

function usage()
{
	echo "Usage: $0 -s sessionID -l urlLink [-c cookieName] [-b biskitPK] [-t biskitType] [-m menuItemPK] [-n buttonLabel] -w workflowPK"
	echo "$0 will send a request to an Exprodo/Calpendo database to ask it to run a user workflow event"
	echo "-s sessionID    Specifies the session ID for this user's session"
	echo "-l urlLink      Specifies the URL for your system. For example 'https://demo.calpendo.com/' or (equivalently) http://demo.calpendo.com/api/"
	echo "-c cookieName   Specifies the name of the cookie for storing the user's session ID. This will be calculated if not provided."
	echo "-b biskitPK     Specifies the primary key of a biskit you would like to pass to the user workflow event. Not useful with a -t option."
	echo "-t biskitType   Specifies the type of a biskit you would like to pass to the user workflow event. Not useful with a -b option."
	echo "-m menuItemPK   Specifies the primary key of a menu item that should be indicated initiated the user workflow event"
	echo "-n buttonLabel  Specifies the label on a button that should be indicated initiated the user workflow event"
	echo "-w workflowPK   Specifies the primary key of the user workflow event that should be run"
	exit 1
}

cookie_given=no

while getopts hs:l:w:b:t:m:n: option
do
	case $option in
		s) session_id=$OPTARG;;
		l) link=$OPTARG;;
		c) cookie_given=yes; cookie_name=$OPTARG;;
		w) workflow=$OPTARG;;
		b) biskitPK=$OPTARG;;
		t) biskitType=$OPTARG;;
		m) menuItem=$OPTARG;;
		n) label="$OPTARG";;
		h) usage;;
		*) usage;;
	esac
done

if [[ -z $session_id ]]
then
    echo "You must specify a -s argument" 1>&2
	usage
fi

if [[ $workflow = 0 ]]
then
    echo "You must specify a -w argument" 1>&2
	usage
fi

getURL $link

if test $cookie_given = no
then
	cookie_name=$($(dirname $0)/get_cookie_name.sh -l $link)
fi

if [[ -z "$cookie_name" ]]
then
	# Either we were given an empty cookie name by the caller
	# or the get_cookie_name.sh script could not get the name.
	# Either way, let's just assume the old default for Calpendo
	cookie_name=session_id-Calpendo
fi

cat << RUN_WORKFLOW_REQUEST > request.json
{
        "sessionID": "$session_id",
        "payload": {
                "state": null,
                "biskitPKs": null,
                "formContent": null,
                "biskitPK": $biskitPK,
                "menuItemPK": $menuItem,
                "biskitTypes": null,
                "biskitType": null,
                "buttonLabel": "$label",
                "awaitEvent": true,
                "userWorkflowEventPK": $workflow,
                "runEvenIfDisabled": true
        }
}
RUN_WORKFLOW_REQUEST

wget -O response.json --no-cookies --header "Cookie: $cookie_name=$session_id" --header="Accept: application/json" --header="Content-Type: application/json" --user=root --password= --post-file=request.json ${link}runUserWorkflowEvent

echo Download = $(jq ".payload.downloadableFileKey" response.json)
echo Message = $(jq ".payload.message" response.json)
echo Message Type = $(jq ".payload.messageType" response.json)
