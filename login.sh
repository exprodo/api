#!/bin/bash

auth=0
user=root
password=
link=

source `dirname $0`/lib.sh

function usage()
{
	echo "Usage: $0 -a authPK -u username -p password -l urlLink"
	echo "$0 will log in to the server and return your session ID"
	echo "-a authPK    Provides the primary key of the authentication method for the user"
	echo "-u username  Specifies the user's name"
	echo "-p password  Provides the user's password"
	echo "-l urlLink   Specifies the URL for your system. For example 'https://demo.calpendo.com/' or (equivalently) http://demo.calpendo.com/api/"
	exit 1
}

while getopts ha:u:p:l:w:b:t:m:n: option
do
	case $option in
		a) auth=$OPTARG;;
		u) user=$OPTARG;;
		p) password=$OPTARG;;
		l) link=$OPTARG;;
		h) usage;;
		*) usage;;
	esac
done

if test "$auth" = 0
then
    echo "You must specify a -a argument"
	usage
fi

#
# Ensure $link ends with "/api/"
#
getURL $link

cat << LOGIN_REQUEST > request.json
{
	"sessionID": null,
	"payload": {
		"username": "$user",
		"password": "$password",
		"authPK": $auth,
		"loginPath": "API"
	}
}
LOGIN_REQUEST

#
# Do not put user and password on the command line in production.
# Use a .wgetrc or .netrc file instead so that the login details
# do not show up in the process table
#
# See man page for wget for more
#
wget --quiet -O response.json --header="Accept: application/json" --header="Content-Type: application/json" --user=$user --password=$password --post-file=request.json ${link}login

session_id=`cat response.json | jq '.payload.sessionID' | sed 's/^"\(.*\)"/\1/'`

echo $session_id
