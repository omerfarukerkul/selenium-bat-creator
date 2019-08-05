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

$text | Out-File  "$filePath\seleniumBat.bat" -Encoding oem -Force

##Zip dosyasini sil
Remove-Item $filePath\* -Include *.zip

#Selenium jar dosyasi indirilir.
$SeleniumJarUrl = "https://selenium-release.storage.googleapis.com/3.12/selenium-server-standalone-3.12.0.jar"
$output = "$filePath\selenium-server-standalone-3.12.0.jar"
(New-Object System.Net.WebClient).DownloadFile($SeleniumJarUrl, $output)



# Get current config Jenkins
###curl -X GET http://developer:developer@localhost:8080/job/test/config.xml -o mylocalconfig.xml

# Post updated config Jenkins
###curl -X POST http://developer:developer@localhost:8080/job/test/config.xml --data-binary "@mymodifiedlocalconfig.xml"
