@echo off

REM ---------------------------------------------------------------
REM Legacy (old Windows) build: Windows 7 SP1 / 8 / 8.1.
REM
REM The default build targets .NET 10, which only runs on Windows 10
REM 1607 or later. This script targets .NET 6, the last runtime that
REM runs on Windows 7 SP1, and produces self-contained single-file
REM executables (the .NET runtime is NOT required on the target).
REM
REM Requirements on the target machine:
REM   * Windows 7 SP1 (or 8 / 8.1)
REM   * Universal C Runtime  (KB2999226)
REM   * SHA-2 code signing support  (KB4474419)
REM   * KB2533623
REM
REM Output: publish\artifacts\win-legacy-x86\CLI and
REM         publish\artifacts\win-legacy-x64\CLI
REM ---------------------------------------------------------------

msbuild /m /t:restore,cli\uupmediaconverter:publish,cli\uupdownload:publish /p:Platform=x86 /p:RuntimeIdentifier=win-x86 /p:UUPMediaTargetFramework=net6.0 /p:LangVersion=latest /p:PublishDir=%CD%\publish\artifacts\win-legacy-x86\CLI /p:SelfContained=true /p:PublishSingleFile=true /p:PublishTrimmed=false /p:Configuration=Release UUPMediaCreator.sln
msbuild /m /t:restore,cli\uupmediaconverter:publish,cli\uupdownload:publish /p:Platform=x64 /p:RuntimeIdentifier=win-x64 /p:UUPMediaTargetFramework=net6.0 /p:LangVersion=latest /p:PublishDir=%CD%\publish\artifacts\win-legacy-x64\CLI /p:SelfContained=true /p:PublishSingleFile=true /p:PublishTrimmed=false /p:Configuration=Release UUPMediaCreator.sln
