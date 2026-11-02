#!/bin/bash

auth=0
user=root
password=
link=
code=

source `dirname $0`/lib.sh

function usage()
{
	echo "Usage: $0 -a authPK -u username -p password -l urlLink [-t twoFACode]"
	echo "$0 will log in to the server and return your session ID"
	echo "-a authPK     Provides the primary key of the authentication method for the user"
	echo "-u username   Specifies the user's name"
	echo "-p password   Provides the user's password"
	echo "-l urlLink    Specifies the URL for your system. For example 'https://demo.calpendo.com/' or (equivalently) http://demo.calpendo.com/api/"
	echo "-t twoFACode  Provides the current code from your authenticator app, if your account uses two factor authentication (2FA)."
	echo "              If 2FA is needed and this is not given, you will be asked for the code."
	exit 1
}

while getopts ha:u:p:l:t: option
do
	case $option in
		a) auth=$OPTARG;;
		u) user=$OPTARG;;
		p) password=$OPTARG;;
		l) link=$OPTARG;;
		t) code=$OPTARG;;
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
wget --quiet -O response.json --content-on-error --header="Accept: application/json" --header="Content-Type: application/json" --user=$user --password=$password --post-file=request.json ${link}login
wget_status=$?

session_id=$(jq -r '.payload.sessionID // empty' response.json 2>/dev/null)

if [[ -z "$session_id" ]]
then
	error=$(jq -r '.errorMessage // .message // empty' response.json 2>/dev/null)
	if [[ -z "$error" && $wget_status -eq 6 ]]
	then
		# HTTP 401: wget discards the server's message, but at login
		# this means the credentials were not accepted
		error="the username, password or authentication method (-a) was not accepted (HTTP 401 Unauthorized)"
	elif [[ -z "$error" && $wget_status -ne 0 ]]
	then
		error=$(describeWgetFailure $wget_status)
	fi
	echo "Login failed: ${error:-no session ID in response.json}" 1>&2
	exit 2
fi

#
# If the user has two factor authentication (2FA) turned on, then the
# session we've just been given is not yet valid. Any other request using it
# will be refused until we send a ValidateTwoFASessionRequest with the
# current code from the user's authenticator app.
#
# The login response tells us whether this is needed ("twofa") and gives us a
# token ("twoFAToken") that must be sent back with the code. The token is
# only valid for a short time, so the code must be sent promptly.
#
twofa=$(jq -r '.payload.twofa // false' response.json)
twofa_token=$(jq -r '.payload.twoFAToken // empty' response.json)

if [[ $twofa = true ]]
then
	if [[ -z "$code" ]]
	then
		if ! [[ -t 0 ]]
		then
			echo "Login failed: this account uses two factor authentication, so you must give the code with -t" 1>&2
			exit 3
		fi

		# Prompt on stderr, so that stdout contains only the session ID
		read -p "Two factor authentication code: " code 1>&2
	fi

	# The 2FA request must carry the session cookie, so we need its name
	cookie_name=$($(dirname $0)/get_cookie_name.sh -l $link)
	cookie_name=$(echo "${cookie_name:-session_id-Calpendo}" | sed 's/ /%20/g')

	cat << VALIDATE_2FA_REQUEST > request.json
{
	"sessionID": "$session_id",
	"payload": {
		"authPK": $auth,
		"sessionID": "$session_id",
		"userSuppliedCode": "$code",
		"sessionValidationToken": "$twofa_token",
		"skipFutureValidation": false
	}
}
VALIDATE_2FA_REQUEST

	wget --quiet -O response.json --content-on-error --no-cookies --header "Cookie: $cookie_name=$session_id" --header="Accept: application/json" --header="Content-Type: application/json" --post-file=request.json ${link}validateTwoFASession
	wget_status=$?

	valid=$(jq -r '.payload.valid // false' response.json 2>/dev/null)
	if [[ $valid != true ]]
	then
		error=$(jq -r '.payload.errorMessage // .errorMessage // .message // empty' response.json 2>/dev/null)
		if [[ -z "$error" && $wget_status -ne 0 ]]
		then
			error=$(describeWgetFailure $wget_status)
		fi
		echo "Two factor authentication failed: ${error:-the code was not accepted}" 1>&2
		exit 3
	fi
fi

echo $session_id
