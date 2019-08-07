Clear-Host
#masaustunde yeni klasor olusturup icerisine cd ile gidilir.
function Set-FolderSavePath {
    $browse = "$HOME\Desktop\otomasyon"
    New-Item -Type directory -Path $browse -Force | Out-Null
    Set-Location -Path $browse
    $browse
}

#userLdap ve hostname bilgilerinin alinmasi.
function Get-UserLdapAndHostname {
    $hostname = [System.Net.Dns]::GetHostName()
    $data = $env:USERNAME, $hostname
    $data
}

function Request-JenkinsXml([string]$jobUrl) {
    # Fill in the blanks
    $UserName = "MAYA10"
    $JenkinsAPIToken = "116f76f5227da692c1167e670480576dfa"
    $JENKINS_URL = "http://10.210.32.22:8080"
    $JOB_URL = $jobUrl

    # Create client with pre-emptive authentication
    # see => http://www.hashemian.com/blog/2007/06/http-authorization-and-net-webrequest-webclient-classes.htm
    $webClient = new-object System.Net.WebClient
    $webclient.Headers.Add("Authorization", "Basic " +
        [System.Convert]::ToBase64String(
            [System.Text.Encoding]::ASCII.GetBytes("$($UserName):$JenkinsAPIToken")))

    # fetch CSRF token as authenticated user
    # see => https://wiki.jenkins-ci.org/display/JENKINS/Remote+access+API
    $crumbURL = $JENKINS_URL + "/crumbIssuer/api/xml"
    $crumbs = [xml]$webClient.DownloadString($crumbURL)

    # set the CSRF token in the headers
    $webclient.Headers.Add($crumbs.defaultCrumbIssuer.crumbRequestField, $crumbs.defaultCrumbIssuer.crumb)

    # GET the job configuration (you don't actually need the CSRF token for this
    # but it's better to get that token once at the top in case you want to do multiple
    # operations e.g. setting parameters on many jobs, in this script)
    $configURL = $JOB_URL + "/config.xml"
    $config = [xml]$webClient.DownloadString($configURL)

    # do whatever transformation you need to the XML

    $config
}

$userData = Get-UserLdapAndHostname  #Array[0] = LDAP , Array[1] = hostname
$filePath = Set-FolderSavePath       #otomasyon klasörü yoksa olusturur varsa otomasyon-yeni adinda klasor olusturur.

##TODO Chrome Versiyonunun ogrenilmesi ve gereken formata getirilmesi.
$chromeVersion = (Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe').'(Default)').VersionInfo.ProductVersion
$chromeVersion = $chromeVersion.ToCharArray()
[array]::Reverse($chromeVersion)
$chromeVersion = -join ($chromeVersion)
$chromeVersion = $chromeVersion.Split(".", 2)
$chromeVersion = $chromeVersion.Get(1)
$chromeVersion = $chromeVersion.ToCharArray()
[array]::Reverse($chromeVersion)
$chromeVersion = -join ($chromeVersion)

#Chrome driver'i halihazirdaki chrome versiyonuna gore indirilir.
$WebResponse = Invoke-WebRequest "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$chromeVersion" 
$WebResponse = $WebResponse.Content
$DownloadUrl = "https://chromedriver.storage.googleapis.com/$WebResponse/chromedriver_win32.zip"
$output = "$filePath\chromeDriver.zip"
(New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $output)

if ($PSVersionTable.PSVersion.ToString().split(".", 2).get(0) -ge 5) { Expand-Archive -path $output -destinationpath $filePath -Force }

##Bat dosyasi yazdir.
$text = 'SETLOCAL
SET JAVA_TOOL_OPTIONS=
SET _JAVA_OPTIONS=
java -Dwebdriver.chrome.driver=\`"chromedriver.exe\`" -jar selenium-server-standalone-3.12.0.jar -role node -port 1453 -hub http://10.210.32.53:4444/grid/register
if  %ERRORLEVEL% == 1 pause
ENDLOCAL'

$text | Out-File  "$filePath\seleniumBat.bat" -Encoding oem 

##Zip dosyasini sil
Remove-Item $filePath\* -Include *.zip

#Selenium jar dosyasi indirilir.
$SeleniumJarUrl = "https://selenium-release.storage.googleapis.com/3.12/selenium-server-standalone-3.12.0.jar"
$output = "$filePath\selenium-server-standalone-3.12.0.jar"
(New-Object System.Net.WebClient).DownloadFile($SeleniumJarUrl, $output)

#Java 8 indirilir ve kurulur.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$URL=(Invoke-WebRequest -UseBasicParsing https://www.java.com/en/download/manual.jsp).Content | %{[regex]::matches($_, '(?:<a title="Download Java software for Windows Online" href=")(.*)(?:">)').Groups[1].Value}
Invoke-WebRequest -UseBasicParsing -OutFile jre8.exe $URL
Start-Process .\jre8.exe '/s REBOOT=0 SPONSORS=0 AUTO_UPDATE=0' -wait
echo $?

#Remove-Item $output -Force

$jobRequest = "$userData[0]_QaSelenium"

$jobResponse = Request-JenkinsXml($jobRequest)

# Get current config Jenkins
###curl -X GET http://MAYA10:113aea2aae91d13fbed3fba5f9d15eab0c@localhost:8080/job/test/config.xml -o mylocalconfig.xml

# Post updated config Jenkins
###curl -X POST http://developer:developer@localhost:8080/job/test/config.xml --data-binary "@mymodifiedlocalconfig.xml"