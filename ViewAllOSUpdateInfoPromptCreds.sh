#!/bin/zsh

read -p "Jamf Pro URL: " URL
read -p "Jamf Pro Username: " userName
read -s -p "Jamf Pro Password: " password
echo ""

# server connection information
#URL="https://instancename.jamfcloud.com"
#userName="username"
#password="password"

# use base64 to encode credentials
encodedCredentials=$( printf "$userName:$password" | iconv -t ISO-8859-1 | base64 -i - )

# generate an auth token
authToken=$( /usr/bin/curl "$URL/api/v1/auth/token" \
--silent \
--request POST \
--header "Authorization: Basic $encodedCredentials" )

# parse authToken for token, omit expiration
token=$( /usr/bin/awk -F \" '/token/{ print $4 }' <<< "$authToken" | /usr/bin/xargs )

/usr/bin/curl --request GET --url $URL'/api/v1/managed-software-updates/plans?page=0&page-size=100000&sort=planUuid%3Aasc' --header "Authorization: Bearer $token" --header "Accept: application/json" 

# expire the auth token
/usr/bin/curl "$URL/api/v1/auth/invalidate-token" \
--silent \
--request POST \
--header "Authorization: Bearer $token"

exit 0