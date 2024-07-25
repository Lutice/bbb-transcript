#!/bin/bash

# Webhook test
force=""

# Default values
url="https://beta.lutice.online/bbb-transcript/aristote_webhook.php"
#url="https://webhook.site/e0c0d369-96d0-48e5-ba55-6e3d25d31265"
configfile="webhook.config"
logfile=""
id=""
status="SUCCESS"
versionId=""
test_flag=true

echo ""
echo "***************************************************"

while [ $# -ge 1 ]; do
	if [ "$1" == "--help" ] || [ "$1" == "--h" ]; then
		echo "Usage: script.sh [OPTIONS]"
		echo ""
		echo "Logs options:"
		echo "  --delete-logs          Clear logs by deleting the file beforehand."
		echo "  --no-delete-logs       Keep the logs."
		echo ""
		echo "Specify request content:"
		echo "  -id <id>               Specify the ID."
		echo "  -status <status>       Specify the status."
		echo "  -versionId <versionId> Specify the version ID."
		echo "  -token <token>         Specify the bearer token. (DEPRECATED: Not used anymore)"
		echo "  --simulate-real        Disable the test flag to simulate a real request."
		echo ""
		echo "Notes:"
		echo "  Except if --delete-logs or --no-delete-logs is specified, the user will be prompted to delete or keep the existing logs."
		echo "  In the case of '-log' being specified, the delete qualifier will behave on the new path as if it was the default path logs."
		exit 0
	elif [ "$1" == "--delete-logs" ]; then
		force=true
		shift
		continue
	elif [ "$1" == "--no-delete-logs" ]; then
		force=false
		shift
		continue
	elif [ "$1" == "--simulate-real" ]; then
		test_flag=false
		shift
		continue
	fi

	# Cannot continue if there are less than 2 arguments (following options require 2)
	if [ $# -lt 2 ]; then
		if [ -n "$1" ]; then
			echo "Unspecified or unregognized argument: $1"
		fi
		break
	fi

	if [ "$1" == "-id" ]; then
		shift
		id="$1"
		shift
		continue
	elif [ "$1" == "-status" ]; then
		shift
		status="$1"
		shift
		continue
	elif [ "$1" == "-versionId" ]; then
		shift
		versionId="$1"
		shift
		continue
	elif [ "$1" == "-token" ]; then
		shift
		bearertoken="$1"
		shift
		continue
	elif [ "$1" == "-logs" ]; then
		shift
		logfile="$1"
		shift
		continue
	fi

	echo "Unregognized argument: $1 - ignoring"
	shift
done

echo "Sending request with the following parameters :"
echo "    Id: $id"
echo "    Status: $status"
echo "    versionId: $versionId"
echo "    Token: $bearertoken"

delete=""

# Prompt only if --no-delete or --delete have NOT been specified
while [ -z "$force" ] && [ "$delete" != "y" ] && [ "$delete" != "n" ]; do
	read -p "Delete last logs ? (y/n) " delete
done

# If it was specified before by the prompt, delete the logs
if [ "$delete" == "y" ] || [ "$force" == "true" ]; then
	rm -f "$logfile"
fi


jsonPayload='{
  "id": "'"$id"'",
  "status": "'"$status"'",
  "initialVersionId": "'"$versionId"'",
  "failureCause": "string"'

# Conditionally append the isTest field
if [ "$test_flag" == true ]; then
  jsonPayload+=", \"isTest\": \"yes\""
fi

# Close the JSON payload
jsonPayload+='
}'


### Make the curl request
curl -X 'POST' \
	"$url" \
	-H 'accept: */*' \
	-H 'Content-Type: application/json' \
	-d "$jsonPayload"

#	-H "Authorization: $bearertoken" \

if [ $? -ne 0 ]; then
	echo "Something went wrong in the request."
fi

exit 0
