#!/bin/bash

auth=0
user=root
password=
link=

source `dirname $0`/lib.sh

function usage()
{
	echo "Usage: $0 -l urlLink"
	echo "$0 will ask the server for the name that should be used for the cookie that stores your session ID"
	echo "-l urlLink   Specifies the URL for your system. For example 'https://demo.calpendo.com/' or (equivalently) http://demo.calpendo.com/api/"
	exit 1
}

while getopts hl: option
do
	case $option in
		l) link=$OPTARG;;
		h) usage;;
		*) usage;;
	esac
done

#
# Ensure $link ends with "/api/"
#
getURL $link

cat << REQUEST > request.json
{
	"sessionID": null,
	"payload": {
	}
}
REQUEST

wget --quiet -O response.json --header="Accept: application/json" --header="Content-Type: application/json" --post-file=request.json ${link}getCookieName

cookie_name=`cat response.json | jq '.payload.cookieName' | sed 's/^"\(.*\)"/\1/'`

echo $cookie_name
