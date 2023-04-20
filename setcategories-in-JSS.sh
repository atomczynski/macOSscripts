#!/bin/bash

#Set catagories for iOS apps

#Grab all the needed info.  Username/password/JAMF Pro URL/CategoryID
read -p "Please enter your JAMF pro username: " userName
read -s -p "Please enter your password (no output here): " userPass
echo ""
read -p "Please enter your JAMF Pro URL (https://instancename.jamfcloud.com): " jamfProURL
read -p "Please enter the Category ID we're adding: " catID

#used for testing purposes only. 
#userName=""
#userPass=""
#jamfProURL=""
#catID=""

#Grab an authtoken and extract it into a usable format.
authToken=$(curl -s -u "$userName:$userPass" $jamfProURL/api/v1/auth/token -X POST)
api_token=$(plutil -extract token raw - <<< "$authToken")

#Uncomment out the next line for troubleshooting if necessary.
#echo $api_token

#Uncomment the following 4 lines for troubeshooting.  Please note! $userPass is the password we entered above.
#echo $userName
#echo $userPass
#echo $jamfProURL
#echo $catID

#List of app ID's separated by returns

appIDList="312
708
773
630
331"

for anAppID in $appIDList
do
curl -s -H "Authorization: Bearer $api_token" "$jamfProURL/JSSResource/mobiledeviceapplications/id/$anAppID" -H "content-type: text/xml" -X PUT -d "<mobile_device_application><self_service><self_service_categories><category><id>$catID</id><display_in>true</display_in></category></self_service_categories></self_service></mobile_device_application>"

echo ""
echo $anAppID
echo ""
done

echo "" #Linebreak

#invalidate the current token.  Shamelessly copied from https://derflounder.wordpress.com/2021/12/10/obtaining-checking-and-renewing-bearer-tokens-for-the-jamf-pro-api/ and modified to work in this script.
authToken=$(/usr/bin/curl "${jamfProURL}/api/v1/auth/invalidate-token" -s -H "Authorization: Bearer ${api_token}" -X POST)

echo "" #line break
echo "All done!" 
