<#
.SYNOPSIS
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名。

.DESCRIPTION
    找出指定文件夹下面符合柯南TV剧的视频文件，并重命名（使用Antigravity CLI）。

.PARAMETER FolderPath
    要搜索的文件夹路径，此参数为必填项。

.PARAMETER TempPath
    临时文件路径，此参数为选填项，默认为脚本所在目录的上一级目录的temp目录。

.PARAMETER Model
    使用的模型。

.PARAMETER Effort
    模型的推理程度。

.EXAMPLE
    .\rename-conan-tv-agy.ps1 -FolderPath "D:\Downloads\Conan"
    找出D:\Downloads\Conan文件夹下面符合柯南TV剧的视频文件，并重命名。
#>



param (
    [Parameter(Mandatory = $true, Position = 0)]
    [System.IO.DirectoryInfo]$FolderPath,
    [Parameter(Mandatory = $false, Position = 1)]
    [System.IO.DirectoryInfo]$TempPath,
    [string]$Model = "gemini-3.8-flash",
    [Parameter(Mandatory = $false)]
    [ValidateSet("low", "medium", "high", "xhigh", "max")]
    [string]$Effort = "medium"
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


$jsonSchema = @"

{
  "type": "object",
  "properties": {
    "title": {
      "type": "string"
    },
    "error": {
      "type": "string"
    }
  },
  "required": ["title", "error"]
}

"@

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
    $tempFile = [System.IO.FileInfo]::new($(Join-Path $TempPath "$($file.BaseName)_640_60_300.webm"))
    if (-not (Test-Path -LiteralPath $tempFile.FullName)) {
        ffmpeg -i $file.FullName -ss 60 -t 300 -vf "scale=640:-1" -c:v libvpx -crf 50 -b:a 50k $tempFile.FullName
    }
    $prompt = @"
``$($tempFile.Name)``是一个名侦探柯南的视频，请找到视频中播报本集标题的画面。
标题画面有如下特点：
1. 是黑色的背景加上白色的文字
2. 在画面的中间是日文标题

找到标题画面后你需要原封不动地提取出那个日文标题，不需要上面的假名，然后以JSON形式回复。
只需要单纯回复提取出的标题作为纯文本，不需要其他内容，回复的结果内容应该只有标题文本，也不需要多余的换行或者说明。

只需要单纯回复提取出的标题作为纯文本，标题不应该包含换行符，下面是一些合法标题：
- コナンと目暮２人の人質（前編）
- 歩美の絵日記事件簿４

如果成功提取到了标题，那么把标题设置到JSON的``title``字段，并且``error``字段设置为空字符串。
如果没有成功提取到标题，那么把JSON的``title``字段设置为空字符串，并且``error``字段设置为失败原因说明。

"@
    #$prompt
    Write-Host -ForegroundColor DarkGray "⏳ Extrating title from $($tempFile.FullName)"
    $result = $prompt | agy --disable-slash-commands --model $Model --effort $Effort --output-format json --json-schema $jsonSchema --add-dir $TempPath | ConvertFrom-Json
    #$result
    $newFileName = $result.structured_output.title
    $errorContent = $result.structured_output.error
    if ($null -eq $newFileName -or $newFileName.Trim() -eq "" -or $newFileName.Trim().Length -eq 0 ) {
        Write-Host -ForegroundColor Yellow "❌ Extrating title failed ( ${errorContent} ), skip"
        continue
    }
    if ($episode -match "^\d+$") {
        $episode = "TV${episode}"
    }
    $newFileName = "名探偵コナン.${episode}.${newFileName}.${resolution}.${coder}.${lang}" + $file.Extension

    if ($fileName -ne $newFileName) {
        Write-Host -ForegroundColor Green "✅ $fileName -> $newFileName"
        Rename-Item -LiteralPath $file.FullName -NewName $newFileName
    }
}

