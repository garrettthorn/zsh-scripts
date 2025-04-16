#! /bin/zsh

#define global variables
pschoolURL="<POWERSCHOOL URL HERE>"
basicAuthToken="<BASIC POWERSCHOOL AUTH TOKEN HERE>"

#function to obtain a refreshed accessToken from PowerSchool
obtainPSAccessToken() {

    psAccessTokenResponse=$( curl -s --location "https://$1/oauth/access_token" \
    --header 'Content-Type: application/x-www-form-urlencoded;charset=UTF-8' \
    --header "Authorization: Basic $2" \
    --data-urlencode 'grant_type=client_credentials' )

    #remove carriage returns, newlines, and tabs from the json string
    psAccessTokenResponse=$( echo "$psAccessTokenResponse" | tr -d '\r' | tr -d '\n' | tr -d '\t')

    #use jq to retrieve access token from JSON return
    psAccessToken=$( echo $psAccessTokenResponse | jq -r ".access_token" )

    echo $psAccessToken

}

#function to retrieve data fields from powerschool API
#add more extensions and expansions by referencing powerschool's API on support.powerschool.com
retrieveStudentInfo() {

    #1 powerschool base url
    #2 student's ID number
    #3 powerschool API access token

    psInfo=$( curl --silent --location "https://$1/ws/v1/district/student?q=local_id%3D%3D$2&expansions=contact%2Cschool_enrollment&extensions=u_studentsuserfields" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: Bearer $3" )

    echo $psInfo

}

#retrieve powerschool API access token
pschoolApiToken=$( obtainPSAccessToken "$pschoolURL" "$basicAuthToken" )


#retrieve student data
returnedStudentData=$( retrieveStudentInfo "$pschoolURL" "$studentId" "$pschoolApiToken" )

