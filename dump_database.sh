#!/bin/bash

session_id=
link=
output=
compress=true
include_data=true
include_structure=true
drop_if_exists=true
no_history=false
no_attachment_data=false

source `dirname $0`/lib.sh

function usage()
{
	echo "Usage: $0 -s sessionID -l urlLink [-c cookieName] [-o outputFile] [-u] [-d] [-H] [-A]"
	echo "$0 will ask an Exprodo/Calpendo database to dump itself, and then download the dump file"
	echo "-s sessionID    Specifies the session ID for this user's session"
	echo "-l urlLink      Specifies the URL for your system. For example 'https://demo.calpendo.com/' or (equivalently) http://demo.calpendo.com/api/"
	echo "-c cookieName   Specifies the name of the cookie for storing the user's session ID. This will be calculated if not provided."
	echo "-o outputFile   Specifies where to save the dump. Defaults to the file name chosen by the server, in the current directory."
	echo "-u              Uncompressed. Asks for a plain .sql file rather than a gzipped .sql.gz file"
	echo "-d              Structure only. Dumps the table definitions but no data"
	echo "-H              No history. Omits data from history and statistics tables (audit log, events, stats, login attempts etc)"
	echo "-A              No attachment data. Omits the stored content of attachments"
	exit 1
}

cookie_given=no

while getopts hs:l:c:o:udHA option
do
	case $option in
		s) session_id=$OPTARG;;
		l) link=$OPTARG;;
		c) cookie_given=yes; cookie_name=$OPTARG;;
		o) output=$OPTARG;;
		u) compress=false;;
		d) include_data=false;;
		H) no_history=true;;
		A) no_attachment_data=true;;
		h) usage;;
		*) usage;;
	esac
done

if [[ -z $session_id ]]
then
	echo "You must specify a -s argument" 1>&2
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

# If you're using an Exprodo Database instead of Calpendo, then the cookie
# name can have a space in it. In that case, it must be URL-encoded.
cookie_name=$(echo "$cookie_name" | sed 's/ /%20/g')

#
# globalOptions apply to every table. The noHistory and noAttachmentData
# flags tell the server to override globalOptions so that no data is dumped
# for the relevant tables (their structure is still dumped).
#
# You can instead supply "tableDumpOptions" as a list of objects, each like
# globalOptions but with a "tableName", to control each table separately.
#
cat << DATABASE_DUMP_REQUEST > request.json
{
	"sessionID": "$session_id",
	"payload": {
		"compress": $compress,
		"noHistory": $no_history,
		"noAttachmentData": $no_attachment_data,
		"tableDumpOptions": null,
		"globalOptions": {
			"tableName": null,
			"useGlobalSettings": true,
			"includeStructure": $include_structure,
			"includeData": $include_data,
			"dropIfExists": $drop_if_exists,
			"selectByColumn": null,
			"minColumnValue": null,
			"maxColumnValue": null
		}
	}
}
DATABASE_DUMP_REQUEST

#
# Step 1: ask the server to dump the database.
#
# The server writes the dump to a temporary file before it responds, so on a
# large database this can take a while. Hence the long read timeout.
# Use --tries=1 because the server refuses a second dump that comes too soon
# after the previous one, so retrying would not help.
# Use --content-on-error so that we still get the JSON error message if the
# request is refused (e.g. no permission, or too soon since the last dump).
#
echo "Requesting database dump. This may take some time..."

wget --quiet -O response.json --tries=1 --read-timeout=3600 --content-on-error --no-cookies --header "Cookie: $cookie_name=$session_id" --header="Accept: application/json" --header="Content-Type: application/json" --post-file=request.json ${link}databaseDump
wget_status=$?

#
# Errors can come back in two forms:
#   {"errorMessage": "..."}                    - rejected by the API layer
#   {"className": "...Exception", "message": "..."} - refused by the request
#                                               itself, e.g. no permission,
#                                               or too soon since the last dump
#
error=$(jq -r '.errorMessage // (if .className then .message // .className else empty end)' response.json 2>/dev/null)
if [[ -n "$error" ]]
then
	echo "Database dump failed: $error" 1>&2
	exit 2
fi

if [[ $wget_status -ne 0 ]]
then
	echo "Database dump failed: $(describeWgetFailure $wget_status)" 1>&2
	exit 2
fi

url=$(jq -r '.payload.url // empty' response.json 2>/dev/null)
if [[ -z "$url" ]]
then
	echo "Database dump failed: no URL found in response.json. The response was:" 1>&2
	head -c 1000 response.json 1>&2
	echo 1>&2
	exit 2
fi

#
# Step 2: download the dump file.
#
# The URL in the response is relative, like "downloads?type=tempfile&key=...",
# and the downloads servlet sits alongside the api servlet rather than under
# it. So take the "api/" off the end of the link and add the relative URL.
#
# The download must use the same session cookie, which means it must be done
# as the same user who asked for the dump. It must also come from the same IP
# address that asked for the dump.
#
download_url="${link%api/}$url"

echo "Downloading database dump from $download_url"

if [[ -n "$output" ]]
then
	wget --quiet -O "$output" --no-cookies --header "Cookie: $cookie_name=$session_id" "$download_url"
else
	# Let the server choose the file name. It will be something like
	# database.Calpendo.yourcalpendo.v11.0.0.2025-01-31.12-00.sql.gz
	wget --quiet --content-disposition --no-cookies --header "Cookie: $cookie_name=$session_id" "$download_url"
fi

status=$?
if [[ $status -ne 0 ]]
then
	echo "Download of database dump failed: $(describeWgetFailure $status)" 1>&2
	exit 3
fi

echo "Database dump downloaded"
