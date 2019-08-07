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
function Request-JenkinsXml([string] $jobUrl,[string] $hostname) {
    # Fill in the blanks
    $UserName = "MAYA10"
    $JenkinsAPIToken = "116f76f5227da692c1167e670480576dfa"
    $JENKINS_URL = "http://10.210.32.22:8080"
    $JOB_URL = $JENKINS_URL + "/job/" + $jobUrl + "`_QaSelenium"

    # Create client with pre-emptive authentication
    # see => http://www.hashemian.com/blog/2007/06/http-authorization-and-net-webrequest-webclient-classes.htm
    $webClient = New-object System.Net.WebClient
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
    $configResponse = $webClient.DownloadString($configURL)
    $config = [xml]$configResponse.Replace('<?xml version=''1.1'' encoding=''UTF-8''?>', '<?xml version=''1.0'' encoding=''UTF-8''?>')

    $config.'maven2-moduleset'.properties.'hudson.model.ParametersDefinitionProperty'.parameterDefinitions.'org.biouno.unochoice.CascadeChoiceParameter'.script.secureScript.script = '
    def displayGridList=[]
    if(remoteRunner.equals("true")){
    
    displayGridList.add("http://'+$hostname+':1453/wd/hub")
    }
    
    return displayGridList'
    # do whatever transformation you need to the XML

    # POST back
    # see => http://stackoverflow.com/questions/5401501/how-to-post-data-to-specific-url-using-webclient-in-c-sharp
    
<#     try {
        $webClient.Encoding = [System.Text.Encoding]::UTF8
        $webclient.Headers.Add([System.Net.HttpRequestHeader]::ContentType, "application/xml")
        $webclient.UploadString($configURL, $config.OuterXml)
    } 
    finally {
        ## reset headers for client re-use if you're processing many jobs
        ## (or .Dispose() the client if you're done)
        $webClient.Headers.Remove([System.Net.HttpRequestHeader]::ContentType)

    } #>

    
    $config
}

function Write-BatFile([string] $filePath) {
    
    ##Bat dosyasi yazdir.
    $text = 'SETLOCAL
    SET JAVA_TOOL_OPTIONS=
    SET _JAVA_OPTIONS=
    java -Dwebdriver.chrome.driver=\`"chromedriver.exe\`" -jar selenium-server-standalone-3.12.0.jar -role node -port 1453 -hub http://10.210.32.53:4444/grid/register
    if  %ERRORLEVEL% == 1 pause
    ENDLOCAL'
    
    $text | Out-File  "$filePath\seleniumBat.bat" -Encoding oem 
    $text
}
function Download-ChromeDriver([string] $filePath) {
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
    $hasDownloaded = $?
    if ($PSVersionTable.PSVersion.ToString().split(".", 2).get(0) -ge 5) { Expand-Archive -path $output -destinationpath $filePath -Force }
        
    ##Zip dosyasini sil
    Remove-Item $filePath\* -Include *.zip
    $hasDownloaded
}
function Download-SeleniumJar([string] $filePath) {
    
    #Selenium jar dosyasi indirilir.
    $SeleniumJarUrl = "https://selenium-release.storage.googleapis.com/3.12/selenium-server-standalone-3.12.0.jar"
    $output = "$filePath\selenium-server-standalone-3.12.0.jar"
    (New-Object System.Net.WebClient).DownloadFile($SeleniumJarUrl, $output)
    $?
}
function Setup-Java([string] $filePath) {
    #Java 8 indirilir ve kurulur.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $URL = (Invoke-WebRequest -UseBasicParsing https://www.java.com/en/download/manual.jsp).Content | % { [regex]::matches($_, '(?:<a title="Download Java software for Windows Online" href=")(.*)(?:">)').Groups[1].Value }
    Invoke-WebRequest -UseBasicParsing -OutFile "$filePath\jre8.exe" $URL
    Start-Process "$filePath\jre8.exe" '/s REBOOT=0 SPONSORS=0 AUTO_UPDATE=0' -Wait
    $?
}

$userData = Get-UserLdapAndHostname  #Array[0] = LDAP , Array[1] = hostname
$userLdap = $userData[0]
$userHostName = $userData[1]
$jobRequest = $userLdap  #$userLdap`_QaSelenium
$jobResponse = Request-JenkinsXml $jobRequest $userHostName

$filePath = Set-FolderSavePath       #otomasyon klasörü olusturur
$hasDownloaded = Download-ChromeDriver($filePath)
$batText = Write-BatFile($filePath)
#Java 8 yüklü değilse yükle.
if (!((Get-Command java | Select-Object -ExpandProperty Version).tostring() -match "^8.0")) {
    $setupJava = Setup-Java($filePath)
}
$downloadSeleniumJar = Download-SeleniumJar($filePath)