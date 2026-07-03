#! /bin/zsh

#note - this script requires at least macOS 15 or a manual install of jq

###############################################################################
#                                                                             #
#           Download & Install Latest Version of swiftDialog                  #
#                                                                             #
# #############################################################################


#get the current version of SwiftDialog
currentVersion=$( /usr/local/bin/dialog --version | cut -d '.' -f 1-3)

#retrieve the URL for the latest version of SwiftDialog
dialogURL=$(curl "https://api.github.com/repositories/346831918/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

#retrieve the latest version number from the provided dialogURL
latestVersion=$(echo "$dialogURL" | awk -F'/' '{sub(/v/, "", $(NF-1)); gsub(/-/, ".", $(NF-1)); print $(NF-1)}')
expectedDialogTeamID="PWA5E9TQ59"

echo "current: $currentVersion"
echo "latest: $latestVersion"

if [ "$currentVersion" = "$latestVersion" ]; then
	echo "User already has the most current version."
else
	workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    
    #download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
    
    #verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
    
    #install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
        /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
    else
        echo "Dialog Team ID verification failed."
        #exit 1 # uncomment this if want script to bail if Dialog install fails
    fi
    #remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  
fi



###############################################################################
#                                                                             #
#               API GET Example (Retrieve Info from API)                      #
#                                                                             #
# #############################################################################

##### Explains:
    ##### Obtaining text input from swiftDialog and turning it into a zsh variable
    ##### Making a curl request to an API
    ##### Taking values from the API response and turning them into zsh variables

#set your API variables
baseUrl="<YOUR APIs URL HERE>"
key="<YOUR API AUTHENTICATION TOKEN HERE - BUT DON'T HARDCODE VARIABLES IN PRODUCTION!"

#call swiftDialog and pass output into a variable 
userResponse=$( /usr/local/bin/dialog \
--title "GET Demo" \
--message "Enter the asset tag" \
--textfield "Asset Tag:" \
--json )

#use jq to obtain what the user submitted
assetTag=$( echo "$userResponse" | jq -r '.["Asset Tag:"]')

echo "The asset tag provided by the user is $assetTag"

#Use curl to make the API call passing the asset tag we received from the user
apiResponse=$( curl -s "$baseUrl?assettag=$assetTag" \
    --request "GET" \
    -H "authtoken: $key" )

#because we haven't plugged in our asset management software's actual url or key, we get no response.
#here's some sample json so we can continue the demo
apiResponse=$(cat << EOF
{
    "assets": [
        {
            "org_serial_number": "C02F6WKEQ6L4",
            "manufacturer": "Apple",
            "model": "MacBook Air",            
            "id": "4860",
            "state": {
                "name": "In Use"
            },
            "asset_tag": "12345",
            "user": {
                "email": "user@demo.com",
                "name": "Example User"
            }
        }
    ],
    "response_status": [
        {
            "status_code": 200,
            "status": "success"
        }
    ],
    "list_info": {
        "row_count": 1
    }
}
EOF
)

#from the json, we can extract certain values we need
serialNumber=$( echo "$apiResponse" | jq -r '.assets.[0].org_serial_number' )
manufacturer=$( echo "$apiResponse" | jq -r '.assets.[0].manufacturer' )
assetId=$( echo "$apiResponse" | jq -r '.assets.[0].id' )
assetState=$( echo "$apiResponse" | jq -r '.assets.[0].state.name' )
userEmail=$( echo "$apiResponse" | jq -r '.assets.[0].user.email' )
userName=$( echo "$apiResponse" | jq -r '.assets.[0].user.name')
responseStatus=$( echo "$apiResponse" | jq -r '.response_status.[0].status' )

echo "$serialNumber"
echo "$manufacturer"
echo "$assetId"
echo "$assetState"
echo "$userEmail"
echo "$userName"
echo "$responseStatus"



###############################################################################
#                                                                             #
#                     API PUT Example (Send Info to API)                      #
#                                                                             #
# #############################################################################

##### Explains:
    ##### Obtaining text & select value inputs from swiftDialog and turning them into zsh variables
    ##### Making a curl request to an API for the PUT method
    ##### Taking values from the API response and turning them into zsh variables
    ##### Using swiftDialog to display progress to your user

#set your API variables
baseUrl="<YOUR APIs URL HERE>"
key="<YOUR API AUTHENTICATION TOKEN HERE - BUT DON'T HARDCODE VARIABLES IN PRODUCTION!"

#call swiftDialog and pass output into a variable; in this example we'll obtain an asset tag AND an asset state
userResponse=$( /usr/local/bin/dialog \
--title "PUT Demo" \
--message "Enter the asset tag and asset state" \
--textfield "Asset Tag:" \
--selecttitle "Asset State:",radio \
--selectvalues "In Use, In Store, Surplus" \
--json )

#use jq to obtain what the user submitted
assetTag=$( echo "$userResponse" | jq -r '.["Asset Tag:"]')
assetState=$( echo "$userResponse" | jq -r '.["Asset State:"].selectedValue')

echo "The asset tag provided by the user is $assetTag"
echo "The asset state provided by the user is $assetState"

#let's use swiftDialog to let the user know we're about to make the change to the asset.
/usr/local/bin/dialog \
--title "Demo" \
--listitem "Making changes to asset,status=wait" \
--listitem "Appending data to Google Sheet" \
--listitem "Sending email to user" \
&

#make the API call to update the asset tag with the provided asset state
apiResponse=$(curl -s "$baseUrl/$assetTag" \
      --request "PUT" \
      -H "authtoken: $key" \
      -H "Content-Type: application/json" \
      -d 'input_data= {
        "asset": {
            "state": {
                "name": '"$assetState"'
            }
        }
    }')

#because we haven't plugged in our asset management software's actual url or key, we get no response.
#here's some sample json so we can continue the demo
apiResponse=$(cat << EOF
{
    "response_status": [
        {
            "status_code": 200,
            "status": "success"
        }
    ]
}
EOF
)

#from the json, we can extract certain values we need
responseStatus=$( echo "$apiResponse" | jq -r '.response_status.[0].status' )

#waiting 3 seconds to simulate waiting for the API
sleep 3

#based on the API status, we can update the notification window
if [[ "$responseStatus" = "success" ]]; then
  echo "listitem: Making changes to asset: success" >> /var/tmp/dialog.log
else
  echo "listitem: Making changes to asset: fail" >>  /var/tmp/dialog.log
fi


#wait 5 seconds, then automatically exit the dialog window
sleep 5
echo "quit:" >> /var/tmp/dialog.log



###############################################################################
#                                                                             #
#                    Send Data to Google Sheets & Send Email                  #
#                                                                             #
# #############################################################################

##### Explains:
    ##### Using the Google Sheets API in order to append data to the last row of a spreadsheet
    ##### Sending the same data via a HTML formatted email using the Gmail API

#first we need to create a access token to use for these calls; don't harcode variables - this is just an example
#typically you'd need a separate project and token for the gmail API, but for this example we'll assume we combined them into one token
refresh_token="<REFRESH-TOKEN>"
clientID="<CLIENT-ID>"
clientSecret="<CLIENT-SECRET>"

#pass refresh_token, clientID, and clientSecret to Google Sheets token endpoint to obtain a new access token
key=$(curl https://oauth2.googleapis.com/token \
--request POST \
--data "access_type=offline&refresh_token=$refresh_token&client_id=$clientID&client_secret=$clientSecret&grant_type=refresh_token")

#use jq to retrieve access token from JSON return
token=$( echo $key | jq -r ".access_token" )




######### Google Sheets #########
#define these values from your Google Sheet
#sheetID is from the URL
sheetId="1hd9e898z728390zjjdlksjjd0z-1kk2sssa"
#sheetName is at the bottom left of the Google Sheet - Sheet1 is the default
sheetName="Sheet1"
#the range of rows you'd like to update; we have 5 values so we're doing A through E
sheetRange="A:E"

#create a URL with these values to be used in the curl statement later
url="https://sheets.googleapis.com/v4/spreadsheets/${sheetId}/values/${sheetName}!${sheetRange}:append?insertDataOption=INSERT_ROWS&valueInputOption=USER_ENTERED"

#these are the values we want to send; normally these values would come from other APIs or inputs from your user, but we're just hardcoding them for simplicity of the example
assetTag="12345"
assetState="In Use"
serialNumber="C02F6WKEQ6L4"
userEmail="user@demo.com"
userName="Example User"

#make the actual API call using curl
sheetsResult=$(curl "$url" \
--request POST \
-H "Authorization: Bearer $token" \
-H "Content-Type: application/json" \
-d "{\"values\": [[\"$assetTag\", \"$assetState\", \"$serialNumber\", \"$userEmail\", \"$userName\"]]}")



######### Gmail #########
#define where you'd like the custom html file to exist temporarily
htmlLocation="/private/tmp/doc.html"

#create the custom html email, putting your variables into the email
cat <<EOF > $htmlLocation
From: Your Name <example@email.com>
To: $userEmail
Subject: Your Device Receipt
Date: $(date -R)
Reply-To: example@email.com
Content-Type: text/html; charset="UTF-8"

<!DOCTYPE html>
<html lang="en">
    <head>
        <title>Demo</title>
    </head>
    <body>
        <h1>Here's the receipt for your device!</h1>
        <p>Your device: $assetTag</p>
        <p>Serial number: $serialNumber</p>
        <p>Asset state: $assetState</p>
        <p>Your name: $userName</p>
    </body>
</html>
EOF

#use the API to send the email file via curl
gmailResult=$( curl "https://gmail.googleapis.com/upload/gmail/v1/users/me/messages/send" \
--request POST \
-H "Authorization: Bearer $token" \
-H "Content-Type: message/rfc822" \
--data-binary @$htmlLocation )

