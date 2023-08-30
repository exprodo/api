# API

These scripts demonstrate how to connect to an Exprodo or Calpendo database
using the same general client JSON API used by the standard browser client.

These are here to demonstrate how this can be done using scripts that should
be simple enough to see what they're doing. However, it is not recommended
that these scripts be used as a matter of course. This is because they are
written in such a way that passwords are specified on the command line, and
so represent a security risk.

Consider these as demonstrations that can get you started rather than a
polished product.

Also, beware that the API this uses is not currently documented. It consists
of around 140 different types of request, each of which might change between
versions.

The instructions in this README use some of the Exprodo REST API and query API.
You can find full descriptions of them in our
[documentation](https://docs.exprodo.com/calpendo/index.html?api.htm).

# Prerequisites

These scripts require program "jq" to be installed, and assume a unix-like
environment. To install jq, then you might use:

    sudo apt install jq

or

    sudo yum install jq

You must also have a user account on a Calpendo (or a non-Calpendo Exprodo
system) so that you can connect using that account. Ideally, that would be
a local account.

# Obtain Session ID

To use the general client API, you must log in and get a session ID.
To see the full options for the log in, run:

    login.sh -h

For this to work, you first need to identify the id number (primary key) of the
authentication method you want to use. You can either work it out using the
web UI, or you can do so using the read-only API like this:

    wget -quiet -O - --user=USER --password=PASSWORD 'https://yourcalpendo/webdav/b/AuthenticationMethod'

where you should replace the "https://yourcalpendo/" with the URL for your
Calpendo, and replace USER and PASSWORD with your username and password.

USER should be a local user (rather than one that authenticates via some
single-sign-on method like Shibboleth).

If you're looking specifically for the local authentication method, then you
can go directly to it with a query API call like this:

    wget -quiet -O - --user=USER --password=PASSWORD 'https://yourcalpendo/webdav/q/AuthenticationMethod/biskitType/eq/LocalAuthenticationMethod?paths=id'

Once you've identified the id number of the authentication method, you can
then use it to allow you to use the general client API rather than the
read-only REST API or query API used above.

First use login.sh along with the user name and password to log in and get a
session ID:

    login.sh -a AUTH_METHOD_ID -u USER -p PASSWORD -l http://yourcalpendo/

where you should replace AUTH_METHOD_ID with the id of the authentication
method.

NOTE: You cannot use this as a means of logging in as a user for any external
authentication method. That is, if it's an authentication method for which
Calpendo does not normally handle the password at all (for example when
you're using single-sign-on, like Shibboleth), then login.sh would not work.

If login.sh works, then it will output the session ID. If it doesn't work, you
might need to remove the "--quiet" option from wget in login.sh to see what
the error was.

# Run User Workflow

Once you have a session ID, then you can use it in further calls. For example,
if you want to run a UserWorkflowEvent, you can do so as follows:

    run_user_workflow.sh -s YOUR_SESSION_ID -l http://yourcalpendo/ -w 300004157686785

Again, you have to find the primary key of the user workflow event to make the call.
There are additional options on run_user_workflow.sh - run it with just the "-h"
option for full details.

All other requests you can make follow the same pattern.

All the scripts will create a file "request.json" and "response.json" in your
current working directory. These are left in case you want to see the detail
of what the script sent and received.

To be able to make sense of big JSON files, I recommend:

* jsonlint.com - online utility for formatting and checking JSON
* jq - command-line JSON processor - https://stedolan.github.io/jq/
* https://www.geany.org/ - for a GUI text editor that can read/write JSON
  files

# Obtaining Cookie Name

Version 11.0 of Exprodo databases use a different name for the cookie it
uses to store the user's session ID. There's a script that will calculate
this for you:

    get_cookie_name.sh -l http://yourcalpendo/

If you use scripts that connect using the internal API, then you will need
to know the cookie name. Note that the cookie name is stable and will
rarely change in the lifetime of your database (although it did change for
version 11.0).

The script run_user_workflow.sh can be given the cookie name, and will
calculate it if you don't provide it. This means it serves as an example
of how to calculate it, although you may wish to hard-code it once you
work out what it is, since it is stable.

# Get Bookings

You can get bookings in various ways. You can do so with the REST API, but
it can only be used to return a single booking or all bookings. There are
likely to be too many for this, so you can instead use the query API to pick
just those bookings you want. For example:

    wget -quiet -O - --user=USER --password=PASSWORD 'https://yourcalpendo/webdav/q/Calpendo.Booking/dateRange.start.date/eq/20210906'

If you want to use the general client API though, you can use the same method
the standard Calpendo client uses. This has been exemplified with the script 
get_bookings_and_templates.sh

You will need to find out the id for the resources you're interested in.

    wget -O - --user=admin --password=admin 'https://yourcalpendo/webdav/b/Calpendo.Resource'

Once you have that, you can make the call like this:

    get_bookings_and_templates.sh -s SESSION_ID -l https://yourcalpendo/ -r RESOURCE_CSV

where you replace SESSION_ID with the session ID returned by login.sh, and
change the URL to that of your Calpendo, and change the RESOURCE_CSV to a
comma-separated list of the id numbers of the resources whose bookings you
want.

You can see the full options available with this script by running:

    get_bookings_and_templates.sh -h

The response you get from this message is one which demonstrates that it is
difficult to interpet the data without either full documentation of it, or an
SDK that will map from the JSON form to something more directly usable.

Neither of those are currently published, and that's why you should use the
REST API or the query API where possible. However, talk to us about what
you're trying to achieve, and we may be able to help you use the general
client API.

# Further Calls

If you want to create a booking, then the REST API or query API won't help you
because they are both read only. In this case, your only chance is to use the
general client API.

The nature of Calpendo is such that there can be custom sub-types of Booking,
each of which could have their own custom properties added. This is akin to
subclassing in an object oriented programming language. This means that
when creating a booking, you would need to specify which of the defined
sub-types of booking you want to create, and you would have to supply values
for all of its properties, including any custom properties.

In lieu of an SDK to help with this, it is recommended to usethe standard web
user interface, and displaying the browser tools to capture network traffic so
that you can create a booking and then inspect the JSON actually sent.

Together with the examples already provided, this may be enough for you to
replicate any of the calls the standard web user interface makes.
