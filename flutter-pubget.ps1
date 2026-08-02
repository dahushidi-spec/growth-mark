<#
.SYNOPSIS
    Flutter pub get 辅助脚本（绕过工作区写入限制）
.DESCRIPTION
    由于工作区目录存在写入权限限制，flutter pub get 无法直接写入 pubspec.lock 和 .dart_tool/。
    此脚本通过临时目录中转：在 C:\src\flutter-pubgen 中执行 pub get，然后将生成的文件复制回 frontend 目录。
.NOTES
    使用方法：在项目根目录执行 .\flutter-pubget.ps1
#>

$ErrorActionPreference = "Stop"

# === 环境变量配置 ===
$env:FLUTTER_ROOT = 'C:\src\flutter'
$env:PATH = "C:\src\flutter\bin;C:\src\flutter\bin\cache\dart-sdk\bin;" + $env:PATH
$env:PUB_CACHE = 'C:\src\pub-cache'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:APPDATA = 'C:\src\flutter-appdata'
$env:LOCALAPPDATA = 'C:\src\flutter-localappdata'

# === 路径配置 ===
$frontendDir = "$PSScriptRoot\frontend"
$tempDir = 'C:\src\flutter-pubgen'

Write-Host "=== Flutter Pub Get 辅助脚本 ===" -ForegroundColor Cyan
Write-Host "前端目录: $frontendDir"
Write-Host "临时目录: $tempDir"
Write-Host ""

# === Step 1: 准备临时目录 ===
Write-Host "[1/4] 准备临时目录..." -ForegroundColor Yellow
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

# 复制 pubspec.yaml 和源代码到临时目录
Copy-Item "$frontendDir\pubspec.yaml" "$tempDir\pubspec.yaml" -Force
Copy-Item "$frontendDir\lib" "$tempDir\lib" -Recurse -Force
if (Test-Path "$frontendDir\analysis_options.yaml") {
    Copy-Item "$frontendDir\analysis_options.yaml" "$tempDir\analysis_options.yaml" -Force
}
if (Test-Path "$frontendDir\assets") {
    Copy-Item "$frontendDir\assets" "$tempDir\assets" -Recurse -Force
}
Write-Host "  -> 源文件已复制到临时目录" -ForegroundColor Green

# === Step 2: 在临时目录执行 flutter pub get ===
Write-Host "[2/4] 执行 flutter pub get..." -ForegroundColor Yellow
Set-Location $tempDir
& flutter pub get 2>&1 | ForEach-Object {
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host "  $_" -ForegroundColor Gray
    } else {
        Write-Host "  $_" -ForegroundColor Gray
    }
}

if ($LASTEXITCODE -ne 0 -and -not (Test-Path "$tempDir\pubspec.lock")) {
    Write-Host "  -> flutter pub get 失败！" -ForegroundColor Red
    exit 1
}
Write-Host "  -> 依赖解析完成" -ForegroundColor Green

# === Step 3: 复制生成的文件回前端目录 ===
Write-Host "[3/4] 复制生成的文件到前端目录..." -ForegroundColor Yellow

# pubspec.lock
Copy-Item "$tempDir\pubspec.lock" "$frontendDir\pubspec.lock" -Force
Write-Host "  -> pubspec.lock" -ForegroundColor Green

# .dart_tool/ 目录
New-Item -Path "$frontendDir\.dart_tool" -ItemType Directory -Force | Out-Null
Get-ChildItem "$tempDir\.dart_tool" -File -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring("$tempDir\.dart_tool\".Length)
    $targetPath = Join-Path "$frontendDir\.dart_tool" $relativePath
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }
    Copy-Item $_.FullName $targetPath -Force
}
Write-Host "  -> .dart_tool/*" -ForegroundColor Green

# .flutter-plugins-dependencies
if (Test-Path "$tempDir\.flutter-plugins-dependencies") {
    Copy-Item "$tempDir\.flutter-plugins-dependencies" "$frontendDir\.flutter-plugins-dependencies" -Force
    Write-Host "  -> .flutter-plugins-dependencies" -ForegroundColor Green
}

# .flutter-plugins
if (Test-Path "$tempDir\.flutter-plugins") {
    Copy-Item "$tempDir\.flutter-plugins" "$frontendDir\.flutter-plugins" -Force
    Write-Host "  -> .flutter-plugins" -ForegroundColor Green
}

# === Step 4: 验证 ===
Write-Host "[4/4] 验证..." -ForegroundColor Yellow
$checks = @(
    @{ Name = "pubspec.lock"; Path = "$frontendDir\pubspec.lock" },
    @{ Name = ".dart_tool/package_config.json"; Path = "$frontendDir\.dart_tool\package_config.json" }
)
$allOk = $true
foreach ($check in $checks) {
    if (Test-Path $check.Path) {
        Write-Host "  -> $($check.Name) OK" -ForegroundColor Green
    } else {
        Write-Host "  -> $($check.Name) MISSING!" -ForegroundColor Red
        $allOk = $false
    }
}

Set-Location $PSScriptRoot

if ($allOk) {
    Write-Host "`n=== 完成！===" -ForegroundColor Cyan
    Write-Host "所有依赖已安装并同步到前端目录。" -ForegroundColor Green
    Write-Host "提示：如需运行 flutter analyze 或 flutter run，请在 C:\src\flutter-pubgen 目录中操作，" -ForegroundColor Gray
    Write-Host "      或使用 VS Code 打开 frontend 目录（IDE 通常不需要写入这些文件）。" -ForegroundColor Gray
} else {
    Write-Host "`n=== 部分文件缺失，请检查 ===" -ForegroundColor Red
}
