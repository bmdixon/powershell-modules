Install-Module SqlServer -AllowClobber

try {

    $nuGetUrl = "https://www.nuget.org/api/v2/package/Microsoft.SqlServer.SqlManagementObjects/"
    $targetPath = "$PSScriptRoot\smo\"
    New-Item -Path $targetPath -ItemType "directory" | Out-Null

    $response = Invoke-WebRequest -Uri $nuGetUrl
    if ($response.StatusCode -ne 200) {
        throw "Unable to download package from $nuGetUrl`: $($response.StatusCode) : $($response.StatusDescription)"
    }

    # save package and decompress to temp folder
    $tempZipFilePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".zip")
    [System.IO.File]::WriteAllBytes($tempZipFilePath, $response.Content)
    $response.BaseResponse.Dispose()
    $tempUnzipFolderPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
    Expand-Archive -Path $tempZipFilePath -DestinationPath $tempUnzipFolderPath
    $tempZipFilePath | Remove-Item

    # copy assemblies to target path and remove temp files
    Copy-Item "$tempUnzipFolderPath\lib\netstandard2.0\*" $targetPath
    $tempUnzipFolderPath | Remove-Item -Recurse

}
catch {
    throw
}