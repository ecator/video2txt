<#
.SYNOPSIS
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名为模板。

.DESCRIPTION
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名为模板，这个脚本不调用AI，只是单纯把文件名整理成固定的格式，方便人工填入实际的标题。（用AI太贵了！！！）

.PARAMETER FolderPath
    要搜索的文件夹路径，此参数为必填项。



.EXAMPLE
    .\rename-conan-tv.ps1 -FolderPath "D:\Downloads\Conan"
    找出D:\Downloads\Conan文件夹下面符合柯南TV剧的视频文件，并重命名为模板。
#>



param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath
)

# 检查文件夹是否存在
if (-not (Test-Path -Path $FolderPath -PathType Container)) {
    Write-Error "FolderPath不存在: $FolderPath"
    exit 1
}

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
    $newFileNamePlaceholder = "{EPISODE_TITLE}"
    if ($episode -match "^\d+$") {
        $episode = "TV${episode}"
    }
    $newFileName = "名探偵コナン.${episode}.${newFileNamePlaceholder}.${resolution}.${coder}.${lang}" + $file.Extension

    if ($fileName -ne $newFileName) {
        Write-Host "$fileName -> $newFileName"
        Rename-Item -LiteralPath $file.FullName -NewName $newFileName
    }
}

