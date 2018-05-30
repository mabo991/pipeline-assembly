@echo off
rem
rem
rem    Licensed to the Apache Software Foundation (ASF) under one or more
rem    contributor license agreements.  See the NOTICE file distributed with
rem    this work for additional information regarding copyright ownership.
rem    The ASF licenses this file to You under the Apache License, Version 2.0
rem    (the "License"); you may not use this file except in compliance with
rem    the License.  You may obtain a copy of the License at
rem
rem       http://www.apache.org/licenses/LICENSE-2.0
rem
rem    Unless required by applicable law or agreed to in writing, software
rem    distributed under the License is distributed on an "AS IS" BASIS,
rem    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem    See the License for the specific language governing permissions and
rem    limitations under the License.
rem
rem    ------------------------------------------------------------------------
rem
rem    This script is adapted from the launcher script of the Karaf runtime:
rem    http://karaf.apache.org/
rem

if not "%ECHO%" == "" echo %ECHO%

setlocal enabledelayedexpansion
set DIRNAME=%~dp0
set PROGNAME=%~nx0
set ARGS=%*
rem Code to return to launcher on failure
rem 0:success, 1:unhandled, 2:user-fixable, 3:fatal(we must fix)
set exitCode=0

set REQUIRED_JAVA_VER=9.0.0

title Pipeline2

if "%PIPELINE2_DATA%" == "" (
    set PIPELINE2_DATA=%appdata%/DAISY Pipeline 2
    if not exist "!PIPELINE2_DATA!" (
      mkdir "!PIPELINE2_DATA!"
    )
)

if not exist "%PIPELINE2_DATA%/log" mkdir "%PIPELINE2_DATA%/log"

goto BEGIN

rem # # SUBROUTINES # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

:warn
    echo %PROGNAME%: %*
    echo %PROGNAME%: %* >> "%PIPELINE2_DATA%/log/daisy-pipeline-launch.log"
goto :EOF

:append_to_classpath
    set filename=%~1
    set suffix=%filename:~-4%
    if %suffix% equ .jar set CLASSPATH=%CLASSPATH%;%PIPELINE2_HOME%\%BOOTSTRAP:/=\%\%filename%
goto :EOF

:check_temp_directory
	if "%TEMP%"=="" (
		call:warn Temporary directory is not set.
		exit /b 1
	)
	mkdir "%TEMP%\foo"
	if not exist "%TEMP%\foo" (
		call:warn Temporary directory is not writable.
		exit /b 1
	)
	rmdir /Q /S "%TEMP%\foo"
goto :EOF

:get_javaHome_version
    rem Strip everything after hyphen
    set JAVA_VER=%JAVA_HOME:*-=%
    rem if nothing was stripped (hyphen not found)
    if "%JAVA_VER%" == "%JAVA_HOME%" exit /b 1
goto :EOF
rem # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

:BEGIN
    call:warn %DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2% %TIME:~0,2%:%TIME:~3,2%:%TIME:~6,2%

    rem # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

    if not "%PIPELINE2_HOME%" == "" call:warn Ignoring predefined value for PIPELINE2_HOME

    set PIPELINE2_HOME=%DIRNAME%..
    if not exist "%PIPELINE2_HOME%" (
        call:warn PIPELINE2_HOME is not valid: !PIPELINE2_HOME!
        set exitCode=3
        goto END
    )

    if not "%PIPELINE2_BASE%" == "" (
        if not exist "%PIPELINE2_BASE%" (
           call:warn PIPELINE2_BASE is not valid: !PIPELINE2_BASE!
           set exitCode=3
           goto END
        )
    )

    if "%PIPELINE2_BASE%" == "" set PIPELINE2_BASE=!PIPELINE2_HOME!

    if not "%PIPELINE2_DATA%" == "" (
        if not exist "%PIPELINE2_DATA%" (
            mkdir "!PIPELINE2_DATA!"
        )
    )

    set LOCAL_CLASSPATH=%CLASSPATH%
    set DEFAULT_JAVA_OPTS=-Xmx1G -XX:MaxPermSize=256M -Dcom.sun.management.jmxremote
    set CLASSPATH=%LOCAL_CLASSPATH%;%PIPELINE2_BASE%\conf
    set DEFAULT_JAVA_DEBUG_OPTS=-Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005

    if "%LOCAL_CLASSPATH%" == "" goto :PIPELINE2_CLASSPATH_EMPTY
        set CLASSPATH=%LOCAL_CLASSPATH%;%PIPELINE2_BASE%\conf
        goto :PIPELINE2_CLASSPATH_END

:PIPELINE2_CLASSPATH_EMPTY
    set CLASSPATH=%PIPELINE2_BASE%\conf

:PIPELINE2_CLASSPATH_END
    rem Support for loading native libraries
    set PATH=%PATH%;%PIPELINE2_BASE%\lib;%PIPELINE2_HOME%\lib
    rem Setup the Java Virtual Machine
    if not "%JAVA%" == "" goto :Check_JAVA_END
        if not "%JAVA_HOME%" == "" goto :TryJavaHome
            call:warn JAVA_HOME not set; results may vary

:TryJRE
    call:check_temp_directory
    if errorLevel 1 (
        set exitCode=3
        goto END
    )

    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Runtime Environment" %TEMP%.\__reg1.txt
    if not exist %TEMP%.\__reg1.txt goto :TryJDK

    type %TEMP%.\__reg1.txt | find "CurrentVersion" > %TEMP%.\__reg2.txt
    if errorlevel 1 goto :TryJDK

    for /f "tokens=2 delims==" %%x in (%TEMP%.\__reg2.txt) do set JavaTemp=%%~x
    if errorlevel 1 goto :TryJDK

    set JavaTemp=%JavaTemp%##
    set JavaTemp=%JavaTemp:                ##=##%
    set JavaTemp=%JavaTemp:        ##=##%
    set JavaTemp=%JavaTemp:    ##=##%
    set JavaTemp=%JavaTemp:  ##=##%
    set JavaTemp=%JavaTemp: ##=##%
    set JavaTemp=%JavaTemp:##=%

    del %TEMP%.\__reg1.txt
    del %TEMP%.\__reg2.txt

    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Runtime Environment\%JavaTemp%" %TEMP%.\__reg1.txt
    if not exist %TEMP%.\__reg1.txt goto :TryJDK

    type %TEMP%.\__reg1.txt | find "JavaHome" > %TEMP%.\__reg2.txt
    if errorlevel 1 goto :TryJDK

    for /f "tokens=2 delims==" %%x in (%TEMP%.\__reg2.txt) do set JAVA_HOME=%%~x
    if errorlevel 1 goto :TryJDK

    del %TEMP%.\__reg1.txt
    del %TEMP%.\__reg2.txt
goto TryJDKEnd

:TryJDK
    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit" %TEMP%.\__reg1.txt
    if not exist %TEMP%.\__reg1.txt (
        call:warn Unable to retrieve JAVA_HOME
        set exitCode=2
        goto END
    )

    type %TEMP%.\__reg1.txt | find "CurrentVersion" > %TEMP%.\__reg2.txt
    if errorlevel 1 (
        call:warn Unable to retrieve JAVA_HOME
        set exitCode=2
        goto END
    )

    for /f "tokens=2 delims==" %%x in (%TEMP%.\__reg2.txt) do set JavaTemp=%%~x
    if errorlevel 1 (
        call:warn Unable to retrieve JAVA_HOME
        set exitCode=2
        goto END
    )

    set JavaTemp=%JavaTemp%##
    set JavaTemp=%JavaTemp:                ##=##%
    set JavaTemp=%JavaTemp:        ##=##%
    set JavaTemp=%JavaTemp:    ##=##%
    set JavaTemp=%JavaTemp:  ##=##%
    set JavaTemp=%JavaTemp: ##=##%
    set JavaTemp=%JavaTemp:##=%

    del %TEMP%.\__reg1.txt
    del %TEMP%.\__reg2.txt

    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit\%JavaTemp%" %TEMP%.\__reg1.txt
    if not exist %TEMP%.\__reg1.txt (
        call:warn Unable to retrieve JAVA_HOME from JDK
        set exitCode=2
        goto END
    )

    type %TEMP%.\__reg1.txt | find "JavaHome" > %TEMP%.\__reg2.txt
    if errorlevel 1 (
        call:warn Unable to retrieve JAVA_HOME
        set exitCode=2
        goto END
    )

    for /f "tokens=2 delims==" %%x in (%TEMP%.\__reg2.txt) do set JAVA_HOME=%%~x
    if errorlevel 1 (
        call:warn Unable to retrieve JAVA_HOME
        set exitCode=2
        goto END
    )

    del %TEMP%.\__reg1.txt
    del %TEMP%.\__reg2.txt

:TryJDKEnd
    rem Check version and binary, set %JAVA%
    if not exist "%JAVA_HOME%" (
        call:warn JavaHome from registry is not valid: "%JAVA_HOME%"
        set exitCode=2
        goto END
    )
    call:get_javaHome_version
    if errorLevel 1 (
      call:warn The registry points to an incompatible JVM; we require at least Java %REQUIRED_JAVA_VER%
      set exitCode=2
      goto END
    )
    set VER_COMP = call "%~dp0\VersionCompare.vbs" %JAVA_VER% %REQUIRED_JAVA_VER%
    if "%VER_COMP%"=="-1" (
        call:warn The registry points to an incompatible JVM %JAVA_VER%; we require at least %REQUIRED_JAVA_VER%
        set exitCode=2
        goto END
    )
    call:warn Found compatible JVM: %JAVA_VER%
    if not exist "%JAVA_HOME%\bin\java.exe" (
        call:warn java.exe not found from registry
        set exitCode=2
        goto END
    )
    set JAVA=%JAVA_HOME%\bin\java
goto Check_JAVA_END

:TryJavaHome
    if not exist "%JAVA_HOME%" (
        call:warn JAVA_HOME is not valid: "%JAVA_HOME%"
        goto TryJRE
    )

    rem Check version and binary, set %JAVA%
    call:get_javaHome_version
    if errorLevel 1 (
      call:warn JAVA_HOME points to an incompatible JVM; we require at least Java %REQUIRED_JAVA_VER%
      goto TryJRE
    )
    set VER_COMP = call "%~dp0\VersionCompare.vbs" %JAVA_VER% %REQUIRED_JAVA_VER%
    if "%VER_COMP%"=="-1" (
        call:warn JAVA_HOME points to an incompatible JVM %JAVA_VER%; we require at least %REQUIRED_JAVA_VER%
        goto TryJRE
    )
    call:warn Found compatible JVM: %JAVA_VER%
    if not exist "%JAVA_HOME%\bin\java.exe" (
        call:warn java.exe not found from JAVA_HOME
        goto TryJRE
    )
    set JAVA=%JAVA_HOME%\bin\java

:Check_JAVA_END
    if "%JAVA_OPTS%" == "" set JAVA_OPTS=%DEFAULT_JAVA_OPTS%

    if "%PIPELINE2_DEBUG%" == "" goto :PIPELINE2_DEBUG_END
    rem Use the defaults if JAVA_DEBUG_OPTS was not set
    if "%JAVA_DEBUG_OPTS%" == "" set JAVA_DEBUG_OPTS=%DEFAULT_JAVA_DEBUG_OPTS%

    set "JAVA_OPTS=%JAVA_DEBUG_OPTS% %JAVA_OPTS%"
    call:warn Enabling Java debug options: %JAVA_DEBUG_OPTS%

:PIPELINE2_DEBUG_END
    if "%PIPELINE2_PROFILER%" == "" goto :PIPELINE2_PROFILER_END

    set PIPELINE2_PROFILER_SCRIPT=%PIPELINE2_HOME%\conf\profiler\%PIPELINE2_PROFILER%.cmd

    if exist "%PIPELINE2_PROFILER_SCRIPT%" goto :PIPELINE2_PROFILER_END (
        call:warn Missing configuration for profiler '%PIPELINE2_PROFILER%': %PIPELINE2_PROFILER_SCRIPT%
        set exitCode=3
        goto END
    )

:PIPELINE2_PROFILER_END
    set BOOTSTRAP=system/bootstrap
    rem Setup the classpath
    pushd "%PIPELINE2_HOME%\%BOOTSTRAP:/=\%"
    for %%G in (*.jar) do call:append_to_classpath %%G
    popd
goto CLASSPATH_END

:CLASSPATH_END
    rem Execute the JVM or the load the profiler
    if "%PIPELINE2_PROFILER%" == "" goto :RUN
        rem Execute the profiler if it has been configured
        call:warn Loading profiler script: %PIPELINE2_PROFILER_SCRIPT%
        call %PIPELINE2_PROFILER_SCRIPT%

:RUN
    SET MAIN=org.apache.felix.main.Main
    SET SHIFT=false
    SET MODE=-Dorg.daisy.pipeline.main.mode=webservice

:RUN_LOOP
    if "%1" == "remote" goto :EXECUTE_REMOTE
    if "%1" == "local" goto :EXECUTE_LOCAL
    if "%1" == "clean" goto :EXECUTE_CLEAN
    if "%1" == "gui" goto :EXECUTE_GUI
    if "%1" == "debug" goto :EXECUTE_DEBUG
goto :EXECUTE

:EXECUTE_REMOTE
    SET OPTS=-Dorg.daisy.pipeline.ws.localfs=false -Dorg.daisy.pipeline.ws.authentication=true
    shift
goto :RUN_LOOP

:EXECUTE_LOCAL
    SET OPTS=-Dorg.daisy.pipeline.ws.localfs=true -Dorg.daisy.pipeline.ws.authentication=false
    shift
goto :RUN_LOOP

:EXECUTE_CLEAN
    rmdir /S /Q "%PIPELINE2_DATA%"
    shift
goto :RUN_LOOP

:EXECUTE_GUI
    SET MODE=-Dorg.daisy.pipeline.main.mode=gui
    shift
goto :RUN_LOOP

:EXECUTE_DEBUG
    if "%JAVA_DEBUG_OPTS%" == "" set JAVA_DEBUG_OPTS=%DEFAULT_JAVA_DEBUG_OPTS%
    set "JAVA_OPTS=%JAVA_DEBUG_OPTS% %JAVA_OPTS%"
    shift
goto :RUN_LOOP

:EXECUTE
    SET ARGS=%1 %2 %3 %4 %5 %6 %7 %8
    rem Execute the Java Virtual Machine
    cd "%PIPELINE2_BASE%"

    rem FIXME: put command in variable and evaluate
    call:warn Starting java: "%JAVA%" %JAVA_OPTS% %OPTS% -classpath "%CLASSPATH%" --add-opens java.base/java.security=ALL-UNNAMED --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-exports=java.base/sun.net.www.protocol.http=ALL-UNNAMED --add-exports=java.base/sun.net.www.protocol.https=ALL-UNNAMED --add-exports=java.base/sun.net.www.protocol.jar=ALL-UNNAMED --add-exports=java.xml.bind/com.sun.xml.internal.bind.v2.runtime=ALL-UNNAMED --add-exports=jdk.xml.dom/org.w3c.dom.html=ALL-UNNAMED --add-exports=jdk.naming.rmi/com.sun.jndi.url.rmi=ALL-UNNAMED --add-modules java.xml.ws.annotation,java.corba,java.transaction,java.xml.bind,java.xml.ws -Dorg.daisy.pipeline.home="%PIPELINE2_HOME%" -Dorg.daisy.pipeline.base="%PIPELINE2_BASE%" -Dorg.daisy.pipeline.data="%PIPELINE2_DATA%" -Dfelix.config.properties="file:%PIPELINE2_HOME:\=/%/etc/config.properties" -Dfelix.system.properties="file:%PIPELINE2_HOME:\=/%/etc/system.properties" %MODE% %PIPELINE2_OPTS% %MAIN% %ARGS%
    call:warn Output is written to daisy-pipeline-java.log

    rem FIXME: sometimes you want to print to terminal
    "%JAVA%" %JAVA_OPTS% %OPTS% -classpath "%CLASSPATH%" --add-opens java.base/java.security=ALL-UNNAMED --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-exports=java.base/sun.net.www.protocol.http=ALL-UNNAMED --add-exports=java.base/sun.net.www.protocol.https=ALL-UNNAMED --add-exports=java.base/sun.net.www.protocol.jar=ALL-UNNAMED --add-exports=java.xml.bind/com.sun.xml.internal.bind.v2.runtime=ALL-UNNAMED --add-exports=jdk.xml.dom/org.w3c.dom.html=ALL-UNNAMED --add-exports=jdk.naming.rmi/com.sun.jndi.url.rmi=ALL-UNNAMED --add-modules java.xml.ws.annotation,java.corba,java.transaction,java.xml.bind,java.xml.ws -Dorg.daisy.pipeline.home="%PIPELINE2_HOME%" -Dorg.daisy.pipeline.data="%PIPELINE2_DATA%" -Dfelix.config.properties="file:%PIPELINE2_HOME:\=/%/etc/config.properties" -Dfelix.system.properties="file:%PIPELINE2_HOME:\=/%/etc/system.properties" %MODE% %PIPELINE2_OPTS% %MAIN% %ARGS% > "%PIPELINE2_DATA%/log/daisy-pipeline-java.log"

rem # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

:END
    call:warn Exiting with value %exitCode%
    endlocal & set exitCode=%exitCode%
    if not "%PAUSE%" == "" pause
goto EXIT

:EXIT
    exit /b %exitCode%
