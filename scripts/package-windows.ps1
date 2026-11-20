# WireDeck Windows 便携包组装：wails build → 内置 adb/aapt2/scrcpy → zip
# 与 .github/workflows/ci.yml 的 build-windows job 保持一致，供 scripts/ship.sh --win32 调用。
# 用法: powershell -ExecutionPolicy Bypass -File Scripts\package-windows.ps1 [-TempRoot D:\Dev\cache\temp]
param(
    # 下载与解压的临时目录。默认使用系统临时目录，构建机可用 -TempRoot 指到大盘。
    [string]$TempRoot = [System.IO.Path]::GetTempPath()
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$downloadDir = Join-Path $TempRoot "wiredeck-pkg\download"
$extractDir = Join-Path $TempRoot "wiredeck-pkg\extract"
Remove-Item (Join-Path $TempRoot "wiredeck-pkg") -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $downloadDir, $extractDir | Out-Null

try {
    # 1. 构建 exe（前端由 wails.json 的 frontend:build 负责）
    Push-Location $root
    try {
        wails build -platform windows/amd64 -o WireDeck.exe
        if ($LASTEXITCODE -ne 0) { throw "wails build 失败（退出码 $LASTEXITCODE）" }
    }
    finally {
        Pop-Location
    }

    $bin = Join-Path $root "build\bin"
    $exe = Join-Path $bin "WireDeck.exe"
    if (-not (Test-Path $exe)) { throw "未找到构建产物 $exe" }

    # 2. platform-tools：adb 与两个 DLL
    $ptZip = Join-Path $downloadDir "platform-tools.zip"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $ptZip -UseBasicParsing
    Expand-Archive -Path $ptZip -DestinationPath (Join-Path $extractDir "pt") -Force
    $pt = Join-Path $bin "platform-tools"
    New-Item -ItemType Directory -Force -Path $pt | Out-Null
    $ptSrc = Join-Path $extractDir "pt\platform-tools"
    Copy-Item (Join-Path $ptSrc "adb.exe") $pt
    Copy-Item (Join-Path $ptSrc "AdbWinApi.dll") $pt -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $ptSrc "AdbWinUsbApi.dll") $pt -ErrorAction SilentlyContinue

    # 3. build-tools：aapt2 用于解析 APK 应用名（platform-tools 里没有）
    $btZip = Join-Path $downloadDir "build-tools.zip"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/build-tools_r34-windows.zip" -OutFile $btZip -UseBasicParsing
    Expand-Archive -Path $btZip -DestinationPath (Join-Path $extractDir "bt") -Force
    $btDir = Get-ChildItem (Join-Path $extractDir "bt") -Directory | Select-Object -First 1
    foreach ($name in @("aapt2.exe", "libwinpthread-1.dll", "libc++_shared.dll")) {
        # r34 起不再附带 libc++_shared.dll，aapt2 为静态链接，缺失不影响；与 CI 口径一致。
        $src = Join-Path $btDir.FullName $name
        if (Test-Path $src) { Copy-Item $src $pt }
    }

    # 4. scrcpy：复用内置 adb，复制时剔除 scrcpy 自带的 adb.exe
    $scZip = Join-Path $downloadDir "scrcpy.zip"
    Invoke-WebRequest -Uri "https://github.com/Genymobile/scrcpy/releases/download/v5.0.1/scrcpy-win64-v5.0.1.zip" -OutFile $scZip -UseBasicParsing
    Expand-Archive -Path $scZip -DestinationPath (Join-Path $extractDir "sc") -Force
    $sc = Join-Path $bin "scrcpy"
    New-Item -ItemType Directory -Force -Path $sc | Out-Null
    $scSrc = Get-ChildItem (Join-Path $extractDir "sc") -Directory | Select-Object -First 1
    Copy-Item (Join-Path $scSrc.FullName "*") $sc -Recurse -Force
    Remove-Item (Join-Path $sc "adb.exe") -ErrorAction SilentlyContinue

    # 5. 打包：顶层放 exe + 两个资源目录
    $zip = Join-Path $bin "WireDeck-windows-amd64.zip"
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Compress-Archive -Path $exe, $pt, $sc -DestinationPath $zip -CompressionLevel Optimal
    Write-Output ("ZIP | " + $zip + " | " + (Get-Item $zip).Length)
}
finally {
    # 下载包与解压目录用完即删，不留缓存
    Remove-Item (Join-Path $TempRoot "wiredeck-pkg") -Recurse -Force -ErrorAction SilentlyContinue
}
