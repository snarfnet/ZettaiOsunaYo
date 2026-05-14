param(
    [string]$Lines = "tools\tts_lines.json",
    [string]$Out = "ZettaiOsunaYo\Resources\Audio",
    [string]$Voice = "Microsoft Haruka Desktop",
    [switch]$Overwrite
)

Add-Type -AssemblyName System.Speech

$items = Get-Content -LiteralPath $Lines -Raw -Encoding UTF8 | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$tempDir = Join-Path $env:TEMP "zettai-osunayo-sapi"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice($Voice)
$synth.Rate = -2
$synth.Volume = 100

foreach ($item in $items) {
    $mp3Path = Join-Path $Out $item.file
    if ((Test-Path -LiteralPath $mp3Path) -and -not $Overwrite) {
        Write-Host "skip $($item.file)"
        continue
    }

    $text = [string]$item.text
    $match = [regex]::Match($text, "「(?<line>[\s\S]+?)」")
    if ($match.Success) {
        $text = $match.Groups["line"].Value
    }

    $wavPath = Join-Path $tempDir ($item.file -replace "\.mp3$", ".wav")
    Write-Host "generate $($item.file)"

    $synth.SetOutputToWaveFile($wavPath)
    $synth.Speak($text)
    $synth.SetOutputToNull()

    ffmpeg -y -hide_banner -loglevel error -i $wavPath -codec:a libmp3lame -b:a 128k $mp3Path
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed for $($item.file)"
    }
}

$synth.Dispose()
Write-Host "done"
