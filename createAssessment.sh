#!/bin/bash
#This script will upload files from a given directory and upload them to a new assessment
FILES=/PATH/TO/THE/FILES/YOU/WANT/TO/UPLOAD/*

email="YOUREMAIL"
password="YOURPASSWORD"

#Required for EMC and Partners
company="YOUR COMPANY NAME"
#Optional for EMC and Partners, Required for Customers
assessmentName="ASSESSMENT NAME"
city="YOUR CITY"
#Use 2 letter codes for state and country
state="YOUR STATE"
country="YOUR COUNTRY"
#Timezones should be written in the Area/Location format (Note that %2f will escape it for you)
timezone="US%2FEastern"
#For available device types look at http://mitrend.com/#api/addFiles
deviceType="VNX"

#Don't change this
apiBase="http://app.mitrend.com/api/assessments"

echo "Creating $assessmentName"
curlResult=$(curl -i -u $email:$password -X POST -d "company=$company&city=$city&country=$country&state=$state&timezone=$timezone" $apiBase)

assessmentId=$(echo $curlResult | sed -e 's/^.*"id":\s\([^,]*\).*$/\1/')
responseCode=$(echo $curlResult | head -n 1 | cut -d\  -f2)

if [ "$responseCode" != "200" ]; then
	echo "Failed to create assessment, $curlResult"
	exit 0
fi 
echo "Created assessment with id $assessmentId"
for f in $FILES
do
  filename="${f##*/}"
  echo "Uploading $f"
  curlResult=$(curl -i -u $email:$password -X POST --form device_type="$deviceType" --form file="@$f" $apiBase/$assessmentId/files)
  responseCode=$(echo $curlResult | head -n 1 | cut -d\  -f2)
  
  #File upload first returns a 100 status code, followed by the actual status code
  if [ "$responseCode" = "100" ]; then
	responseCode=$(echo "$curlResult" | head -3 | tail -1 | cut -d\  -f2)
  fi
  if [ "$responseCode" != "200" ]; then
	echo "Unable to upload file $filename, $curlResult"
	exit 0
fi
done
echo "Submitting Assessment"
curlResult=$(curl -i -u $email:$password -X POST  $apiBase/$assessmentId/submit)
responseCode=$(echo $curlResult | head -n 1 | cut -d\  -f2)
if [ "$responseCode" != "200" ]; then
	echo "Failed to submit assessment, $curlResult"
	exit 0
fi 

echo "Your assessment was successfully submitted"