#Requires -Version 2.0

<#
    .SYNOPSIS
        Downloads, unpacks, and prepares a portable
        Java development environment.
        Big thanks to https://github.com/toksaitov/AndroidStudioPortable
#>

# Set the path to the assets directory
$Assets = ".\assets"

# Change the working directory to the assets directory
Set-Location -Path $Assets

# Definitions
. ".\Definitions.ps1"

# Helpers
. ".\Helpers.ps1"

# Steps

# Download and unpack lessmsi to be able to unpack
# a 7-Zip installer later.
$ToolsAreRequired = !(Test-Path -Path $OracleJDKDirectory)

if ($ToolsAreRequired -And !(Test-Path -Path $LessMSIDirectory))
{
    if (!(Test-Path -Path $LessMSIArchive))
    {
        Write-Host "Get LessMSI" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $LessMSIURL -OutFile $LessMSIArchive
    }
    Write-Host "Expand LessMSI" -ForegroundColor Cyan
    Expand-Archive -Path $LessMSIArchive
}

# Download and unpack the 7-Zip installer.
if ($ToolsAreRequired -And !(Test-Path -Path $7zDirectory))
{
    if (!(Test-Path -Path $7zInstaller))
    {
        Write-Host "Get 7-Zip" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $7zURL -OutFile $7zInstaller
    }

    Write-Host "Use LessMSI to unpack 7zip" -ForegroundColor Cyan
    & ".\$LessMSIDirectory\$LessMSIExecutable" 'x' $7zInstaller
}

# Check the architecture of the OS and change to 64bit if necessary.
if ([System.Environment]::Is64BitProcess) {
    Write-Host "Detected 64bit OS, switching..." -ForegroundColor Green
    $OracleJDK = $OracleJDK64
    $OracleJDKInstaller = $OracleJDKInstaller64
    $OracleJDKURL = $OracleJDKURL64
    $OracleJDKDirectory = $OracleJDKDirectory64
    $OracleJDKBinariesDirectory = $OracleJDKBinariesDirectory64
}

# Download and unpack an Oracle JDK installer without administrative rights.
if (!(Test-Path -Path $OracleJDKDirectory))
{
    if (!(Test-Path -Path $OracleJDKInternalArchive))
    {
        if (!(Test-Path -Path $OracleJDKInternalCAB))
        {

            if (!(Test-Path -Path $OracleJDKInstaller))
            {
                # Download the Oracle JDK installer accepting the
                #     `Oracle Binary Code License Agreement for Java SE`

				$Url = $OracleJDKURL
				$OutFile = $OracleJDKInstaller
                Write-Host "Download Java JDK $OracleJDK" -ForegroundColor Yellow
				Invoke-WebRequest -Uri $Url -OutFile $OutFile -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }

            # Unpack the Oracle JDK installer with 7-Zip.
            Write-Host "Unpack JDK installer" -ForegroundColor Cyan
            & ".\$7zDirectory\$7zExecutable" 'e' $OracleJDKInstaller "$OracleJDKInternalCABPath\$OracleJDKInternalCAB" '-y'
        }

        # Unpack the Oracle JDK Tools CAB with 7-Zip.
        Write-Host "Unpack JDK archive" -ForegroundColor Cyan
        & ".\$7zDirectory\$7zExecutable" 'e' $OracleJDKInternalCAB "$OracleJDKInternalArchive" '-y'
    }

    Write-Host "Unpack JDK" -ForegroundColor Cyan
    & ".\$7zDirectory\$7zExecutable" 'x' $OracleJDKInternalArchive "-o$OracleJDKDirectory" '-y'
}

# Unpack Oracle JDK `.pack` files with the unpack200
# utility bundled with the JDK.
Write-Host "Expand JDK files" -ForegroundColor Cyan
$GetChildItemParameters = @{
    Path = $OracleJDKDirectory
    Filter = '*.pack'
}

$PackFiles = Get-ChildItem @GetChildItemParameters -Recurse

if ($PackFiles)
{
    foreach ($File in $PackFiles)
    {
        $PackFileName = $File.FullName
        $JarFileName = "$($File.DirectoryName)\$($File.BaseName).jar"

        & "$OracleJDKBinariesDirectory\unpack200" '-r' $PackFileName $JarFileName
    }
}

# Don't Remove temporary files.
$LessMSIRootDirectory = Get-RelativeRootDirectory -RelativePath $LessMSIDirectory
$7zRootDirectory = Get-RelativeRootDirectory -RelativePath $7zDirectory

$TemporaryFiles = @(
    $LessMSIArchive,
    $LessMSIRootDirectory,
    $7zInstaller,
    $7zRootDirectory,
    $OracleJDKInstaller,
    $OracleJDKInternalCAB,
    $OracleJDKInternalArchive
)

$RemoveItemParameters = @{
    Path = $TemporaryFiles
    ErrorAction = 'SilentlyContinue'
}

Remove-Item @RemoveItemParameters -Recurse -Force

# Generate a batch file to create env variables JDK.

$BatchContent = @"
@echo off
REM
REM Create temporary environment variables for JDK.
REM
REM This file is automatically generated. Please, do not edit this file.
REM

SETX JAVA_HOME %~dp0$OracleJDKDirectory
for /f "skip=2 tokens=3*" %%1 in ('reg query HKCU\Environment /v PATH') do @if [%%2]==[] ( @setx PATH "%%~1;%JAVA_HOME\bin" ) else ( @setx PATH "%%~1 %%~2;%JAVA_HOME\bin" )

"@

$NewItemParameters = @{
    Path = './start.bat'
    Type = 'File'
    Value = $BatchContent
}
$BatchFile = $NewItemParameters['Path']
New-Item @NewItemParameters -Force
Write-Host "Wrote $BatchFile" -ForegroundColor Green

Write-Host "Running $Assets$BatchFile" -ForegroundColor Yellow
./start.bat
Set-Location ../
# The end.
Write-Host "`nDone." -ForegroundColor Green

Write-Host "`nPLEASE RESTART YOUR SHELL FOR THE CHANGES TO TAKE EFFECT" -ForegroundColor Red