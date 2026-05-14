$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Paste your OpenAI API key, then press Enter."
Write-Host "The key will not be shown on screen."
$secureKey = Read-Host "OPENAI_API_KEY" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)

try {
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    if ([string]::IsNullOrWhiteSpace($plainKey)) {
        throw "API key is empty."
    }

    $env:OPENAI_API_KEY = $plainKey
    python tools\generate_tts.py
}
finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    Remove-Item Env:\OPENAI_API_KEY -ErrorAction SilentlyContinue
}
