@echo off
REM
REM Create temporary environment variables for JDK.
REM
REM This file is automatically generated. Please, do not edit this file.
REM

SETX JAVA_HOME %~dp0
for /f "skip=2 tokens=3*" %%1 in ('reg query HKCU\Environment /v PATH') do @if [%%2]==[] ( @setx PATH "%%~1;%JAVA_HOME\bin" ) else ( @setx PATH "%%~1 %%~2;%JAVA_HOME\bin" )
