$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"

$backendEnv = Join-Path $PSScriptRoot "..\backend\.env"
if (Test-Path $backendEnv) {
    Get-Content $backendEnv | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split '=', 2
            if ($parts.Length -eq 2) {
                $key = $parts[0].Trim()
                $val = $parts[1].Trim().Trim('"')
                [Environment]::SetEnvironmentVariable($key, $val, 'Process')
            }
        }
    }
}

mvn $args
