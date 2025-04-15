#! /bin/zsh

#this script is used to determine if a VPN is still connected by checking the reported public IP address of a PC
#if your own public IP address is reported, an email notification is sent and the network adapter is disabled (this has only been tested on macOS 15.4 but could certainly work on other versions)

#set a variable for my own public IP address
myPublicIp="38.39."

#location of the html file path
htmlTxtLocation="/example/path.html"

#set up email parameters for sending via smtps
rtmpUrl="smtps://smtp.gmail.com:465"
rtmpFrom="example@gmail.com"
rtmpTo="example@gmail.com"
rtmpCredentials="example@gmail.com:PASSWORD"

fileUpload="/private/tmp/text.txt"

mailFrom="vpn.alert <$rtmpFrom>"
mailTo="$rtmpTo"
mailSubject="VPN Alert!"
mailReplyTo="example@gmail.com"
mailCC=""

#obtain the public IP address
reportedPublicIpAddress=$( curl ipinfo.io/ip )

echo "Reported IP address is $reportedPublicIpAddress"

#check to see if the public IP address starts with 38.39 - the public IP address for NESPARC
if [[ "$reportedPublicIpAddress" == "$myPublicIp"* ]]; then

    reportedDate=$( date )
    pcName=$( hostname )
    echo "Public address reported!"
    cat <<EOF > $htmlTxtLocation
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Network Alert</title>
  </head>
  <body>
    <p>
      Public address reported at <strong>$reportedDate</strong>!
      <br><br>
      Ethernet adapter on <strong>$pcName</strong> has been disabled.
    </p>
  </body>
</html>
EOF
    publicAddressFlag=true

else

    echo "Using VPN; everything is cool!"

fi

#if the public IP address flag matches
if [ "$publicAddressFlag" = true ]; then

    #base64 encode the html
    messageBase64=$(cat $htmlTxtLocation | base64)

    echo "From: $mailFrom
To: $mailTo
Subject: $mailSubject
Reply-To: $mailReplyTo
Cc: $mailCC
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=\"MULTIPART-MIXED-BOUNDARY\"

--MULTIPART-MIXED-BOUNDARY
Content-Type: multipart/alternative; boundary=\"MULTIPART-ALTERNATIVE-BOUNDARY\"

--MULTIPART-ALTERNATIVE-BOUNDARY
Content-Type: text/html; charset=utf-8
Content-Transfer-Encoding: base64
Content-Disposition: inline

$messageBase64
--MULTIPART-ALTERNATIVE-BOUNDARY--" > $fileUpload

    echo "--MULTIPART-MIXED-BOUNDARY--" >> $fileUpload

    echo "Sending email..."
    curl -s "$rtmpUrl" \
        --mail-from "$rtmpFrom" \
        --mail-rcpt "$rtmpTo" \
        --ssl -u "$rtmpCredentials" \
        -T "$fileUpload" -k --anyauth
    res=$?

    echo $res

    #pause for 25 seconds
    sleep 25

    #disable the network adapter
    networksetup -setnetworkserviceenabled "Ethernet" off

fi