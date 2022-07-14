#!/bin/bash

token=""
pod=""
tCount=""

Auth_fun ()
{
        ##Taking credentials to generate auth token
        read -p "Enter the API server URL e.g gateway.qg2.apps.qualys.com: " pod
        read -p "Enter Pod's username: " usr
        read -s -p "Enter Pod's password: " pass
        echo ""
        echo ""

        ##Generating Auth Token
        token=$(curl -s -k -X POST https://$pod/auth -d "username=$usr&password=$pass&token=true" -H "Content-Type: application/x-www-form-urlencoded")

        ###Verifying the credentials
        auth=$(echo "$token" |  grep "authentication_exceptions")

        if [ -n "$auth" ]
        then
                echo -e "\e[1;31mAuthentication Failed\e[0m: Username or Password is incorrect"
                exit 1
        elif [ -z "$pod" ]
        then
                echo -e "\e[1;31mAuthentication Failed\e[0m: No POD details found"
                exit 1
        elif [ -z "$token" ]
        then
                echo -e "\e[1;31mAuthentication Failed\e[0m: Not able to generate Auth Token"
                exit 1
        else
                echo ""
        fi
}

request_fun_count ()
{
        echo    "{}" > request.json
}

Count_API_Call ()
{
    count=$(curl -s -X POST https://$pod/fim/v3/assets/count -H "authorization: Bearer $token" -H 'content-type: application/json' -d @request.json)
    tCount=$(echo $count | sed 's|}| |g' | cut -d ':' -f2)
}



request_fun_search ()
{
        echo    "{
    \"filter\": \"agentService.status:\`FIMC_STOPPED\` or agentService.status:\`FIM_DRIVER_LOADED_FAILURE\` or agentService.status:\`FIM_DRIVER_UNLOADED\` or agentService.status:\`FIM_DISABLED\`\",
\"pageSize\": $tCount
}" > request.json
}

Search_API_Call()
{
    curl -s -X POST https://$pod/fim/v3/assets/search -H "authorization: Bearer $token" -H 'content-type: application/json' -d @request.json > output.json
}

Data_Format()
{
    echo -e "\nFollowing is the list of Assets on which FIM is activated but not running. Such assets are non compliant as per PCI DSS Requirement 11.5\n"
    echo "Host Name | IP Address | Agent Version | Operating System | Last LoggedOn User | Agent Status | Agent OS Status | Manifest Status | FIM Activated"
    jq . output.json | jq '.[].data | (.name + " | " + .interfaces[0].address + " | " + .agentVersion + " | " + .operatingSystem + " | " + .lastLoggedOnUser + " | " + .agentService.status + " | " + .agentService.osStatus + " | " + .manifest.status + " | " + (.activated | tostring))' | sed 's|"| |g'
}

CSV_fun()
{
    echo -e "\n\nList of Assets on which FIM is activated but not running is created under assets_list.csv"
    echo "Host Name,IP Address,Agent Version,Operating System,Last LoggedOn User,Agent Status,Agent OS Status,Manifest Status,FIM Activated" > assets_list.csv
    jq '.[].data | (.name + "," + .interfaces[0].address + "," + .agentVersion + "," + .operatingSystem + "," + .lastLoggedOnUser + "," + .agentService.status + "," + .agentService.osStatus + "," + .manifest.status + "," + (.activated | tostring))' output.json | sed 's|"| |g' >> assets_list.csv
}

Auth_fun
request_fun_count
Count_API_Call
request_fun_search
Search_API_Call
Data_Format
CSV_fun

rm -rf request.json
rm -rf output.json