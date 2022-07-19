#!/bin/bash
#DEFAULT_PASSWORD=${controller-default-password}
#NEW_PASSWORD=${controller-password}
#CONTROLLER_ADDRESS=${self.network_interface.0.access_config.0.nat_ip}
CURRENT_PASSWORD=
NEW_PASSWORD=
CONTROLLER_ADDRESS=

usage()
{
    echo "usage: change-controller-password.sh [[[--current-password password ] [--new-password password ] [--controller-address address]] | [--help]]"
}

while [ "$1" != "" ]; do
    case $1 in
        --current-password )    shift
                                CURRENT_PASSWORD=$1
                                ;;
        --new-password ) shift  
                                NEW_PASSWORD=$1
                                ;;
        --controller-address )  shift  
                                CONTROLLER_ADDRESS=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

until $(curl -k -X GET --output /dev/null --silent --head --fail https://$CONTROLLER_ADDRESS); do
    sleep 10
done
# Login to the Controller with the default credentials and save the session cookies
COOKIE=$(curl -k --silent --output /dev/null -c - --location --request POST "https://$CONTROLLER_ADDRESS/login" --form username="admin" --form password="$CURRENT_PASSWORD")
# Setup CSRF Token Cookie
TOKEN=$(echo $COOKIE |  grep -o -E '.csrftoken.{0,33}' | sed -e 's/^[ \t]*csrftoken[ \t]//')
# Setup avi-sessionid Cookie
SESSIONID=$(echo $COOKIE | grep -o -E '.avi-sessionid.{0,33}' | sed -e 's/^[ \t]*avi-sessionid[ \t]//')
# Change Password
curl -v -k --location --request PUT "https://$CONTROLLER_ADDRESS/api/useraccount" \
--header "x-csrftoken: $TOKEN" \
--header "referer: https://$CONTROLLER_ADDRESS/" \
--header 'Content-Type: application/json' \
--header "Cookie: csrftoken=$TOKEN; avi-sessionid=$SESSIONID; sessionid=$SESSIONID" \
--data "{
\"username\": \"admin\",
\"password\": \"$NEW_PASSWORD\",
\"old_password\": \"$CURRENT_PASSWORD\"
}"