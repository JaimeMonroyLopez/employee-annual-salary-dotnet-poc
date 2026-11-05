# escape=`
# (Windows paths use "\", so the backtick is used as the line-continuation character.)

# MVCApp (ASP.NET MVC 5, .NET Framework 4.8) on IIS, built with a MULTI-STAGE build.
# WINDOWS containers: Docker Desktop must be in "Windows containers" mode.
# Build context = repository root (see docker-compose.yml and the root .dockerignore).

# ---------------------------------------------------------------------------
# Stage 1 "build": compile and publish the site.
# The SDK image already has MSBuild, NuGet, the web build targets and the
# .NET Framework 4.8 targeting pack, so nothing has to be installed on the host.
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022 AS build

WORKDIR C:/src
COPY . .

# NuGet packages are committed in packages/, so no restore step is needed.
RUN msbuild FrontEnd\MVCApp.csproj /nologo /v:minimal `
    /p:Configuration=Release `
    /p:DeployOnBuild=true `
    /p:DeployDefaultTarget=WebPublish `
    /p:WebPublishMethod=FileSystem `
    /p:PublishUrl=C:\publish `
    /p:DeleteExistingFiles=true

# ---------------------------------------------------------------------------
# Stage 2 (final): run it on IIS.
# Only the published site is copied from the "build" stage: the final image
# carries no SDK, no source code and no intermediate files.
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2022

WORKDIR /inetpub/wwwroot
COPY --from=build C:/publish .
