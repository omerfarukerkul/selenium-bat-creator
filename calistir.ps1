Clear-Host
function Set-FolderSavePath {
    #[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    Add-Type -AssemblyName System.Windows.Forms
    #[System.Windows.Forms.Application]::EnableVisualStyles()
    $browse = New-Object System.Windows.Forms.FolderBrowserDialog
    $browse.ShowNewFolderButton = $true
    $browse.Description = "Dosyalari kaydedecek dizini Secin"
    $browse.RootFolder = "Desktop"
    $browse.SelectedPath = $browse.RootFolder

    $loop = $true
    while ($loop) {
        if ($browse.ShowDialog() -eq "OK") {
            $loop = $false
            Set-Location -Path $browse.SelectedPath
        }
        else {
            Add-Type -AssemblyName Microsoft.VisualBasic
            $res = [Microsoft.VisualBasic.Interaction]::MsgBox('Islemi Iptal Ettiniz.', 'RetryCancel,SystemModal,Information', 'Dosya yolu belirle')
            if ($res -eq "Cancel") {
                #Ends script
                return 1
            }
        }
    }
    $browse.SelectedPath
    $browse.Dispose()
}

function Get-UserLdapAndHostname {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Kullanici LDAP bilgisi.'
    $form.Size = New-Object System.Drawing.Size(300, 200)
    $form.StartPosition = 'CenterScreen'

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75, 120)
    $OKButton.Size = New-Object System.Drawing.Size(75, 23)
    $OKButton.Text = 'Tamam'
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150, 120)
    $CancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $CancelButton.Text = 'Iptal'
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(280, 20)
    $label.Text = 'Lutfen Kullanici LDAP Bilgisini Giriniz:'
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10, 40)
    $textBox.Size = New-Object System.Drawing.Size(260, 20)
    $textBox.Text = $env:USERNAME
    $form.Controls.Add($textBox)

    $form.Topmost = $True
    $form.MaximizeBox = $False
    $form.MinimizeBox = $False
    $form.FormBorderStyle = 'Fixed3D'

    $form.Add_Shown( { $textBox.Select() })
    $result = $form.ShowDialog()

    if ($result -eq "OK") {
        $hostname = [System.Net.Dns]::GetHostName()
        $data = $textBox.Text.ToUpper(), $hostname
        $data
    }
}

$userData = Get-UserLdapAndHostname  #Array[0] = LDAP , Array[1] = hostname
$filePath = Set-FolderSavePath


##TODO Onceki Islemleri yap


##TODO Bat dosyasi yazdir.
$text = "get sample Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Integer imperdiet consectetur eros a posuere.
Sed rutrum suscipit posuere. In sed massa dui. Nullam nec nulla a tellus fermentum feugiat.
Nullam eu purus nec est consectetur tincidunt eget eget leo. Interdum et malesuada fames ac ante ipsum primis in faucibus.
Morbi arcu urna, pretium vitae finibus at, fermentum quis felis.
Duis ut neque condimentum, fringilla nulla non, dictum risus.
Praesent lobortis ullamcorper felis, eu efficitur eros imperdiet vel.
Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae;"
$text | Out-File "$filePath\seleniumBat.bat" 


##Zip dosyasini sil
Remove-Item $filePath\* -Include *.zip


# Get current config Jenkins
###curl -X GET http://developer:developer@localhost:8080/job/test/config.xml -o mylocalconfig.xml

# Post updated config Jenkins
###curl -X POST http://developer:developer@localhost:8080/job/test/config.xml --data-binary "@mymodifiedlocalconfig.xml"
