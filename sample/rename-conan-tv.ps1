<#
.SYNOPSIS
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名。

.DESCRIPTION
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名。

.PARAMETER FolderPath
    要搜索的文件夹路径，此参数为必填项。

.PARAMETER Video2TxtPath
    video2txt的路径，此参数为选填项，默认为脚本所在目录的上一级目录。

.EXAMPLE
    .\rename-conan-tv.ps1 -FolderPath "D:\Downloads\Conan"
    找出D:\Downloads\Conan文件夹下面符合柯南TV剧的视频文件，并重命名。
#>



param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,
    [Parameter(Mandatory = $false)]
    [string]$Video2TxtPath = ""
)

# 检查文件夹是否存在
if (-not (Test-Path -Path $FolderPath -PathType Container)) {
    Write-Error "FolderPath不存在: $FolderPath"
    exit 1
}
if ($Video2TxtPath -eq "") {
    $Video2TxtPath = Split-Path -Path $PSScriptRoot -Parent
}
if (-not (Test-Path -Path $Video2TxtPath -PathType Container)) {
    Write-Error "Video2TxtPath不存在: $Video2TxtPath"
    exit 1
}

$prompt = Join-Path -Path $PSScriptRoot -ChildPath "rename-conan-tv-prompt.txt"

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
        Write-Host "Skip: $fileName"
        continue
    }

    Write-Host "fileName: $fileName"
    Write-Host "  episode: $episode"
    Write-Host "  resolution: $resolution"
    Write-Host "  coder: $coder"
    Write-Host "  lang: $lang"
    $newFileName = uv run --directory $Video2TxtPath main.py -f $file.FullName -p $prompt -a -s 60 -e 300
    if($? -eq $false -or $newFileName -eq "") {
        Write-Host -ForegroundColor Yellow "  Get title failed, skip"
        continue
    }
    if ($episode -match "^\d+$") {
        $episode = "TV${episode}"
    }
    $newFileName = "名探偵コナン.${episode}.${newFileName}.${resolution}.${coder}.${lang}" + $file.Extension

    if ($fileName -ne $newFileName) {
        Write-Host "$fileName -> $newFileName"
        Rename-Item -LiteralPath $file.FullName -NewName $newFileName
    }
}

