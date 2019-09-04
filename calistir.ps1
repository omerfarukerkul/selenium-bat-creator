Clear-Host

#masaustunde yeni klasor olusturup icerisine cd ile gidilir.
function Set-FolderSavePath {
    $timestamp = Get-DateFormat
    $browse = ("$HOME\Desktop\otomasyon-selenium-bat-$timestamp") 
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
function Request-JenkinsXml([string] $userLdap, [string] $hostname) {
    # Fill in the blanks
    $UserName = "MAYA10"
    $JenkinsAPIToken = "116f76f5227da692c1167e670480576dfa"
    $JENKINS_URL = "http://10.210.32.22:8080"
    $JOB_URL = $JENKINS_URL + "/job/" + $userLdap + "`_QaSelenium"

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
    $webClient.Encoding = [System.Text.Encoding]::UTF8
    $configResponse = $webClient.DownloadString($configURL)
    $config = [xml]$configResponse.Replace('<?xml version=''1.1'' encoding=''UTF-8''?>', '<?xml version=''1.0'' encoding=''UTF-8''?>')

    $config.'maven2-moduleset'.properties.'hudson.model.ParametersDefinitionProperty'.parameterDefinitions.'org.biouno.unochoice.CascadeChoiceParameter'.script.secureScript.script = 
    '
def displayGridList=[]
if(remoteRunner.equals("true")){

displayGridList.add("http://' + $hostname + ':1453/wd/hub")
}
return displayGridList'
    # do whatever transformation you need to the XML

    # POST back
    # see => http://stackoverflow.com/questions/5401501/how-to-post-data-to-specific-url-using-webclient-in-c-sharp
    
    try {
        $webClient.Encoding = [System.Text.Encoding]::UTF8
        $webclient.Headers.Add([System.Net.HttpRequestHeader]::ContentType, "text/html;charset=UTF-8")
        $webclient.UploadString($configURL, $config.OuterXml)
    } 
    finally {
        ## reset headers for client re-use if you're processing many jobs
        ## (or .Dispose() the client if you're done)
        $webClient.Headers.Remove([System.Net.HttpRequestHeader]::ContentType)
    } 

    
    $config
}
function Write-BatFile([string] $filePath) {
    ##Bat dosyasi yazdir.
    $text = 'SETLOCAL
    SET JAVA_TOOL_OPTIONS=
    SET _JAVA_OPTIONS=
    java -Dwebdriver.chrome.driver=chromedriver.exe -jar selenium-server-standalone-3.12.0.jar -role node -port 1453 -hub http://10.210.32.15:4444/grid/register -browser "browserName=chrome, version=ANY, maxInstances=10, platform=WINDOWS"
    if  %ERRORLEVEL% == 1 pause
    ENDLOCAL'
    
    $text | Out-File  "$filePath\seleniumBat.bat" -Encoding oem 
    $text
}
function Download-ChromeDriver([string] $filePath) {
    if (Test-Path -Path "$filePath\chromedriver.exe") {
        return 0;
    }
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
    Get-FileFromURL -URL $DownloadUrl -Filename $output
    #(New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $output)
    $hasDownloaded = $?
    if ($PSVersionTable.PSVersion.ToString().split(".", 2).get(0) -ge 5) { Expand-Archive -path $output -destinationpath $filePath -Force }
        
    ##Zip dosyasini sil
    Remove-Item $filePath\* -Include *.zip
    $hasDownloaded
}
function Download-SeleniumJar([string] $filePath) {
    if (Test-Path -Path "$filePath\selenium-server-standalone-3.12.0.jar") {
        return 0;
    }
    #Selenium jar dosyasi indirilir.
    $SeleniumJarUrl = "https://selenium-release.storage.googleapis.com/3.12/selenium-server-standalone-3.12.0.jar"
    $output = "$filePath\selenium-server-standalone-3.12.0.jar"
    Get-FileFromURL -URL $SeleniumJarUrl -Filename $output
    #(New-Object System.Net.WebClient).DownloadFile($SeleniumJarUrl, $output)
    $?
}
function Setup-Java([string] $filePath) {
    if ((Test-Path -Path "$filePath\jre8.exe") -eq "False") {
        #Java 8 indirilir ve kurulur.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $URL = (Invoke-WebRequest -UseBasicParsing https://www.java.com/en/download/manual.jsp).Content | % { [regex]::matches($_, '(?:<a title="Download Java software for Windows [(]64-bit[)]" href=")(.*)(?:">)').Groups[1].Value }
        Get-FileFromURL -URL $URL -Filename "$filePath\jre8.exe"
    }
    #Invoke-WebRequest -UseBasicParsing -OutFile "$filePath\jre8.exe" $URL
    Start-Process "$filePath\jre8.exe" '/s REBOOT=0 SPONSORS=0 AUTO_UPDATE=0' -Wait
    $result = $?
    Remove-Item -Path "$filePath\jre8.exe" -Force
    $result
}
function Get-TimeStamp {
    
    return "[{0:MM/dd/yy}_{0:HH:mm:ss}]" -f (Get-Date)
    
}

function Get-DateFormat {
    
    return "{0:MM_dd_yy}" -f (Get-Date)
    
}

function Get-FileFromURL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [System.Uri]$URL,
        [Parameter(Mandatory, Position = 1)]
        [string]$Filename
    )

    process {
        try {
            $request = [System.Net.HttpWebRequest]::Create($URL)
            $request.set_Timeout(5000) # 5 second timeout
            $response = $request.GetResponse()
            $total_bytes = $response.ContentLength
            $response_stream = $response.GetResponseStream()

            try {
                # 256KB works better on my machine for 1GB and 10GB files
                # See https://www.microsoft.com/en-us/research/wp-content/uploads/2004/12/tr-2004-136.pdf
                # Cf. https://stackoverflow.com/a/3034155/10504393
                $buffer = New-Object -TypeName byte[] -ArgumentList 256KB
                $target_stream = [System.IO.File]::Create($Filename)

                $timer = New-Object -TypeName timers.timer
                $timer.Interval = 500 # Update progress every second
                $timer_event = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
                    $Global:update_progress = $true
                }
                $timer.Start()

                do {
                    $count = $response_stream.Read($buffer, 0, $buffer.length)
                    $target_stream.Write($buffer, 0, $count)
                    $downloaded_bytes = $downloaded_bytes + $count

                    if ($Global:update_progress) {
                        $percent = $downloaded_bytes / $total_bytes
                        $status = @{
                            completed  = "{0,6:p2} Completed" -f $percent
                            downloaded = "{0:n0} MB of {1:n0} MB" -f ($downloaded_bytes / 1MB), ($total_bytes / 1MB)
                            speed      = "{0,7:n0} KB/s" -f (($downloaded_bytes - $prev_downloaded_bytes) / 1KB)
                            eta        = "eta {0:hh\:mm\:ss}" -f (New-TimeSpan -Seconds (($total_bytes - $downloaded_bytes) / ($downloaded_bytes - $prev_downloaded_bytes)))
                        }
                        $progress_args = @{
                            Activity        = "Downloading $URL"
                            Status          = "$($status.completed) ($($status.downloaded)) $($status.speed) $($status.eta)"
                            PercentComplete = $percent * 100
                        }
                        Write-Progress @progress_args

                        $prev_downloaded_bytes = $downloaded_bytes
                        $Global:update_progress = $false
                    }
                } while ($count -gt 0)
            }
            finally {
                if ($timer) { $timer.Stop() }
                if ($timer_event) { Unregister-Event -SubscriptionId $timer_event.Id }
                if ($target_stream) { $target_stream.Dispose() }
                # If file exists and $count is not zero or $null, than script was interrupted by user
                if ((Test-Path $Filename) -and $count) { Remove-Item -Path $Filename }
            }
        }
        finally {
            if ($response) { $response.Dispose() }
            if ($response_stream) { $response_stream.Dispose() }
        }
    }
}

$filePath = Set-FolderSavePath       #otomasyon klasörü olusturur
Write-Host "$(Get-TimeStamp) Masaustune otomasyon klasoru olusturuldu..."

Write-Host "$(Get-TimeStamp) Kullanici Bilgileri aliniyor..."
$userData = Get-UserLdapAndHostname  #Array[0] = LDAP , Array[1] = hostname
$userLdap = $userData[0]
$userHostName = $userData[1]
$jobRequest = $userLdap  #$userLdap`_QaSelenium

$jobResponse = Request-JenkinsXml $jobRequest $userHostName
Write-Host "$(Get-TimeStamp) Jenkins bilgileri ayarlandi..."

$hasDownloaded = Download-ChromeDriver $filePath
Write-Host "$(Get-TimeStamp) Latest chrome driver indirildi..."

$batText = Write-BatFile $filePath
Write-Host "$(Get-TimeStamp) Bat dosyasi yazildi..."

#Java 8 yüklü değilse yükle.
if (!((Get-Command java | Select-Object -ExpandProperty Version).tostring() -match "^8.0")) {
    $setupJava = Setup-Java $filePath
    Write-Host "$(Get-TimeStamp) Java versiyon 8 basariyla yuklendi..."
}

Write-Host "$(Get-TimeStamp) Selenium jar indiriliyor lutfen bekleyin..."
$downloadSeleniumJar = Download-SeleniumJar $filePath
if ($downloadSeleniumJar) {
    Write-Host "$(Get-TimeStamp) Selenium jar indirildi..."
}
else {
    Write-Host "$(Get-TimeStamp) Selenium jar indirilemedi program yoneticisine basvurun..."
}
explorer .