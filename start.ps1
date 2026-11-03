param([switch]$Cloud)
$root = $PSScriptRoot
$adb = "C:\Android\Sdk\platform-tools\adb.exe"
if (Test-Path $adb) { & $adb reverse tcp:8000 tcp:8000 | Out-Null }
if ($Cloud) {
    $env:LISTENAI_PROVIDER = "groq"
    $env:GROQ_API_KEY = [Environment]::GetEnvironmentVariable("GROQ_API_KEY", "User")
}
Set-Location "$root\backend"
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
