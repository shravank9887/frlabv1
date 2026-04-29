@echo off
SETLOCAL EnableDelayedExpansion

rem
rem  Copyright 2016-2025 Ping Identity Corporation. All Rights Reserved
rem
rem This code is to be used exclusively in connection with Ping Identity
rem Corporation software or services. Ping Identity Corporation only offers
rem such software or services to legal entities who have entered into a
rem binding license agreement with Ping Identity Corporation.
rem

set debug_suspend="n"
set debug_port="*:6006"
set debug=

rem check environment
for /f %%f in ('dir amster*.jar /b') do set amster_jar=%%f
if not defined amster_jar (
    echo Could not find amster jar
    exit /B
)
if not DEFINED JAVA_HOME (
    echo "JAVA_HOME not set"
    exit /B
)

rem check args
for %%x in (%*) do (
    if "%%x" == "-d" set debug=-agentlib:jdwp=transport=dt_socket,server=y,suspend=%debug_suspend%,address=%debug_port% -Dorg.slf4j.simpleLogger.defaultLogLevel=DEBUG
)


"!JAVA_HOME!\bin\java.exe" %debug% -Djava.awt.headless=true -jar %amster_jar% %*
