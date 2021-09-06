#!/bin/bash

session_id=
link=
resourcePKs=
myProjects=false
bookerPK=0
ownerPK=0
projectPK=0
from=$(date +%Y%m%dT00:00:00.000)
to=$(date +%Y%m%dT23:59:59.999)

source `dirname $0`/lib.sh

function usage()
{
	echo "Usage: $0 -s sessionID -l urlLink [-h] [-p projectPK] [-b bookerPK] [-o ownerPK] [-m] [-f from] [-t to] -r resources"
	echo "$0 will send a request to an Exprodo/Calpendo database to ask it to run a user workflow event"
	echo "-s sessionID    Specifies the session ID for this user's session"
	echo "-l urlLink      Specifies the URL for your system. For example 'https://demo.calpendo.com/' or (equivalently) http://demo.calpendo.com/api/"
	echo "-b bookerPK     Specifies the primary key of the user that should be the booker of all returned bookings. Default is zero, which means no filtering on booker"
	echo "-o ownerPK      Specifies the primary key of the user that should be the owner of all returned bookings. Default is zero, which means no filtering on owner"
	echo "-p projectPK    Specifies the primary key of the project associated with all returned bookings. Default is zero, which means no filtering on project"
	echo "-m              Specifies that all returned bookings should be for one of my projects. The default is that it is not restricted to my projects."
	echo "-r resources    Specifies a comma-separated list of the primary keys of resources whose bookings should be returned"
	echo "-f from         Specifies the date/time from which bookings should be returned. Format should be yyyymmddTHH:MM:SS.SSS with a default of the start of today"
	echo "-t to           Specifies the date/time to which bookings should be returned. Format should be yyyymmddTHH:MM:SS.SSS with a default of the end of today"
	echo "-r resources    Specifies a comma-separated list of the primary keys of resources whose bookings should be returned"
	echo "-h              Shows this help message"
	exit 1
}

while getopts hs:l:mb:o:p:r:f:t: option
do
	case $option in
		s) session_id=$OPTARG;;
		l) link=$OPTARG;;
		m) myProjects=true;;
		b) bookerPK=$OPTARG;;
		o) ownerPK=$OPTARG;;
		p) projectPK=$OPTARG;;
		r) resources=$OPTARG;;
		f) from=$OPTARG;;
		t) to=$OPTARG;;
		h) usage;;
		*) usage;;
	esac
done

if [[ -z $session_id ]]
then
    echo "You must specify a -s argument" 1>&2
	usage
fi

if [[ -z $resources ]]
then
    echo "You must specify a -r argument" 1>&2
	usage
fi

getURL $link

cat << GET_BOOKINGS_AND_TEMPLATES_REQUEST > request.json
{
	"sessionID": "$session_id",
	"payload": {
		"automatable":true,
		"approved":true,
		"requested":true,
		"tentative":true,
		"denied":false,

		"bookingResources":[$resources],
		"from":"$from",
		"to":"$to",

		"projectPK":$projectPK,
		"ownerPK":$ownerPK,
		"myProjects":$myProjects,
		"bookerPK":$bookerPK,
		"resolutionMinutes":30,
		"cancelled":false,
		"requireBookings":true,
		"requireTemplates":false,
		"templatesAllProjects":true
	}
}
GET_BOOKINGS_AND_TEMPLATES_REQUEST

wget -O response.json --no-cookies --header "Cookie: session_id-Calpendo=$session_id" --header="Accept: application/json" --header="Content-Type: application/json" --user=root --password= --post-file=request.json ${link}getBookingsAndTemplates
