#Either change these values in the script, or enter them as arguments
[CmdletBinding()]
Param
(
    [string]$path="C:\YOUR\PATH\TO\FILES",
	[string]$ftpPath="c:\mitrend2\apiSamples\ftpExample.txt",
	[string]$email=,
	[string]$password=,
	#Required for EMC and Partners
	[string]$company="YOUR COMPANY NAME",
	#Optional for EMC and Partners, Required for Customers
	[string]$assessmentName="ASSESSMENT NAME",
	#Use 2 letter codes for state and country
	[string]$city = "YOUR CITY",
	[string]$state="MA",
	[string]$county = "US",
	#Timezones should be written in the Area/Location format (Note that %2f will escape it for you)
	[string]$timezone="US%2FEastern",
	#For available device types look at http://mitrend.com/#api/addFiles
	[string]$deviceType="Clariion"
)

$apiBase="https://app.mitrend.com/api"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $email,$password)))
$body = @{
company=$company
assessment_name=$assessmentName
city=$city
state=$state
timezone=$timezone
}

echo "Creating $assessmentName"
try{
    $content =  Invoke-RestMethod  "$apiBase/assessments" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Post -Body $body
}catch [System.Net.WebException] {
        Write-Error( "FAILED to reach '$URL': $_" )
        throw $_
}
$assessmentId=$content.id

$fileUrl="$apiBase/assessments/$assessmentId/files"

#Powershell doesn't provide a way to do multi part form encoding, this code is taken from http://stackoverflow.com/questions/25075010/upload-multiple-files-from-powershell-script
function Send-Results {
    param (
        [parameter(Mandatory=$True,Position=1)] [ValidateScript({ Test-Path -PathType Leaf $_ })] [String] $file,
        [parameter(Mandatory=$True,Position=2)] [string] $url,
		[parameter(Mandatory=$True,Position=3)] [string] $deviceType,
		[parameter(Mandatory=$True,Position=3)] [string] $base64AuthInfo
    )
    $fileBin = [IO.File]::ReadAllBytes($file)
    

    # Convert byte-array to string (without changing anything)
    #
    
    $fileEnc = [System.Convert]::ToBase64String($fileBin)

    <#
    # PowerShell does not (heh) have built-in support for making 'multipart' (i.e. binary file upload compatible)
    # form uploads. So we have to craft one...
    #
    # This is doing similar to: 
    # $ curl -i -F "file=@file.any" -F "computer=MYPC" http://url
    #
    # Boundary is anything that is guaranteed not to exist in the sent data (i.e. string long enough)
    #    
    # Note: The protocol is very precise about getting the number of line feeds correct (both CRLF or LF work).
    #>
    $boundary = [System.Guid]::NewGuid().ToString()

    $LF = "`r`n"
    $bodyLines = (
        "--$boundary",
		"content-transfer-encoding: base64",
		"Content-Disposition: form-data; content-transfer-encoding: `"base64`"; name=`"file`"; filename=`" [System.IO.Path]::GetFileName $file`"$LF",
        $fileEnc,
       "--$boundary",
        "Content-Disposition: form-data; name=`"device_type`"$LF",
        $deviceType,
        "--$boundary--$LF"
        ) -join $LF
	
    try {
        # Returns the response gotten from the server (we pass it on).
        #
        Invoke-RestMethod -Uri $url -Method Post -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -ContentType "multipart/form-data; boundary=`"$boundary`"" -TimeoutSec 20 -Body $bodyLines
    }
    catch [System.Net.WebException] {
        Write-Error( "FAILED to reach '$URL': $_" )
        throw $_
    }
}

if([System.IO.File]::Exists($path)){
    $paths=Get-ChildItem $path
    foreach($subPath in $paths)
    {
            $fullPath = Join-Path $path -childPath $subPath
            echo $fullPath.name
            Write-Host "Uploading $fullpath $fileUrl"
            $fileBody={
                device_type=$deviceType
                File = Get-Content($fullPath) -Raw
            }
            Send-Results -file $fullPath -url $fileUrl -deviceType $deviceType -base64AuthInfo $base64AuthInfo
    }
}

if([System.IO.File]::Exists($ftpPath)){
    $reader = [System.IO.File]::OpenText($ftpPath)
    try {
        for() {
            $line = $reader.ReadLine()
            if ($line -eq $null) { break }
            # process the line
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $email,$password)))
            $body = @{
                device_type=$deviceType
                ftpUrl= $line
            }
            $content =  Invoke-RestMethod  $fileUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Post -Body $body
        }
        }
    finally {
        $reader.Close()
    }
}

$content =  Invoke-RestMethod "$apiBase/assessments/$assessmentId/submit" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Post -Body $body
