<#
.SYNOPSIS
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名。

.DESCRIPTION
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名（使用Gemini CLI）。

.PARAMETER FolderPath
    要搜索的文件夹路径，此参数为必填项。

.PARAMETER TempPath
    临时文件路径，此参数为选填项，默认为脚本所在目录的上一级目录的temp目录。

.EXAMPLE
    .\rename-conan-tv-gemini-cli.ps1 -FolderPath "D:\Downloads\Conan"
    找出D:\Downloads\Conan文件夹下面符合柯南TV剧的视频文件，并重命名。
#>



param (
    [Parameter(Mandatory = $true, Position = 0)]
    [System.IO.DirectoryInfo]$FolderPath,
    [Parameter(Mandatory = $false, Position = 1)]
    [System.IO.DirectoryInfo]$TempPath
)

# 设置编码为 UTF8 以防止捕获外部命令输出时出现乱码
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8


# 检查文件夹是否存在
if (-not (Test-Path -Path $FolderPath.FullName -PathType Container)) {
    Write-Error "FolderPath不存在: $FolderPath"
    exit 1
}
if ($TempPath -eq $null) {
    $TempPath = Join-Path -Path $(Get-Item $PSScriptRoot).Parent.FullName -ChildPath "temp"
}
if (-not (Test-Path -Path $TempPath.FullName -PathType Container)) {
    Write-Error "TempPath不存在: $TempPath"
    exit 1
}

$prompt = Get-Content -Raw (Join-Path -Path $PSScriptRoot -ChildPath "rename-conan-tv-prompt.txt")

$files = Get-ChildItem -Path $FolderPath -Recurse -File


foreach ($file in $files) {
    $fileName = $file.Name
    $matchFlag = $true
    if ($fileName -notmatch "CONAN") {
        $matchFlag = $false
    }
    if ($fileName -match "\[((DR)?\d+)\]") {
        $episode = $matches[1]
    }
    else {
        $matchFlag = $false
    }
    if ($fileName -match "\[(\d+P)\]") {
        $resolution = $matches[1]
    }
    else {
        $matchFlag = $false
    }
    if ($fileName -match "\[((AVC|H264|HEVC)_(AAC))\]") {
        $coder = $matches[1]
    }
    else {
        $matchFlag = $false
    }
    if ($fileName -match "\[(((CHS|CHT|JP)_?)+)\]") {
        $lang = $matches[1]
    }
    else {
        $matchFlag = $false
    }

    if ($matchFlag -eq $false) {
        Write-Host -ForegroundColor DarkGray "Skip: $fileName"
        continue
    }

    Write-Host "fileName: $fileName"
    Write-Host "  episode: $episode"
    Write-Host "  resolution: $resolution"
    Write-Host "  coder: $coder"
    Write-Host "  lang: $lang"
    $newFileName = ""
    Push-Location $TempPath
    $tempFile = "$($file.BaseName)_640_60_300.webm"
    if (-not (Test-Path -LiteralPath $tempFile)) {
        ffmpeg -i $file.FullName -ss 60 -t 300 -vf "scale=640:-1" -c:v libvpx -crf 50 -b:a 50k $tempFile
    }
    $tempFile = $tempFile.Replace("\", "/")
    $tempFile = $tempFile.Replace("[", "\[")
    $tempFile = $tempFile.Replace("]", "\]")
    $tempFile = $tempFile.Replace("(", "\(")
    $tempFile = $tempFile.Replace(")", "\)")
    "@$tempFile " | gemini -p $prompt -m gemini-2.5-flash | Set-Variable -Name newFileName
    $newFileName
    Pop-Location
    if ($? -eq $false -or $newFileName -eq "") {
        Write-Host -ForegroundColor Yellow "  Get title failed, skip"
        continue
    }
    if ($episode -match "^\d+$") {
        $episode = "TV${episode}"
    }
    $newFileName = "名探偵コナン.${episode}.${newFileName}.${resolution}.${coder}.${lang}" + $file.Extension

    if ($fileName -ne $newFileName) {
        Write-Host -ForegroundColor Green "$fileName -> $newFileName"
        Rename-Item -LiteralPath $file.FullName -NewName $newFileName
    }
}

