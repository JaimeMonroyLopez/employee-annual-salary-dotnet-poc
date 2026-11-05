# Optional shortcut: checks that Docker is ready, then builds and starts the app with docker compose.
# Everything is compiled inside Docker, so only Docker Desktop is needed on this machine.
# Usage: .\docker\build-and-run.ps1 [-Port 8080]
param([int]$Port = 8080)
# Not 'Stop': docker writes its progress to stderr, and Windows PowerShell would treat that as an error.
# Failures are detected through $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'

$compose = Join-Path $PSScriptRoot 'docker-compose.yml'

# 1. Docker must be running, in Windows containers mode
$os = docker version --format '{{.Server.Os}}' 2>$null
if (-not $os) {
    throw 'Docker is not running. Start Docker Desktop and try again.'
}
if ($os -ne 'windows') {
    throw "Docker is in '$os' mode. Docker Desktop -> right click the whale icon -> 'Switch to Windows containers...'"
}

# 2. Build the image (multi-stage: compile + IIS) and start the container
$env:HOST_PORT = $Port
docker compose -f $compose up -d --build
if ($LASTEXITCODE -ne 0) { throw "docker compose failed (exit code $LASTEXITCODE)." }

Write-Host ""
Write-Host "Ready: http://localhost:$Port/"
Write-Host "Stop:  docker compose -f docker/docker-compose.yml down"
