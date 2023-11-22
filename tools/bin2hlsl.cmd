@echo off
goto :init

:header
    echo %__NAME% v%__VERSION%
    echo bin2hlsl
    echo Calls dxil-spirv and spirv-cross to convert bin files to hlsl.
    echo.
    goto :eof

:usage
    echo USAGE:
    echo   %__BAT_NAME% "inputfile" "outputfile" 
    echo.
    echo.  /?, --help           shows this help
    echo.  /v, --version        shows the version
    echo.  /e, --verbose        shows detailed output
    goto :eof

:version
    if "%~1"=="full" call :header & goto :eof
    echo %__VERSION%
    goto :eof

:missing_argument
    call :header
    call :usage
    echo.
    echo ****    MISSING "INPUT"    ****
    echo.
    goto :eof

:init
    set "__NAME=%~n0"
    set "__VERSION=0.01"
    set "__YEAR=2023"

    set "__BAT_FILE=%~0"
    set "__BAT_PATH=%~dp0"
    set "__BAT_NAME=%~nx0"

    set "OptHelp="
    set "OptVersion="
    set "OptVerbose="

    set "bin2hlslInput="
    set "bin2hlslOutput="
    set "NamedFlag="

:parse
    if "%~1"=="" goto :validate

    if /i "%~1"=="/?"         call :header & call :usage "%~2" & goto :end
    if /i "%~1"=="-?"         call :header & call :usage "%~2" & goto :end
    if /i "%~1"=="--help"     call :header & call :usage "%~2" & goto :end

    if /i "%~1"=="/v"         call :version      & goto :end
    if /i "%~1"=="-v"         call :version      & goto :end
    if /i "%~1"=="--version"  call :version full & goto :end

    if /i "%~1"=="/e"         set "OptVerbose=yes"  & shift & goto :parse
    if /i "%~1"=="-e"         set "OptVerbose=yes"  & shift & goto :parse
    if /i "%~1"=="--verbose"  set "OptVerbose=yes"  & shift & goto :parse

    if not defined bin2hlslInput     set "bin2hlslInput=%~1"     & shift & goto :parse
    if not defined bin2hlslOutput  set "bin2hlslOutput=%~1"  & shift & goto :parse

    shift
    goto :parse

:validate
    if not defined bin2hlslInput call :missing_argument & goto :end

:main
    if defined OptVerbose (
        echo **** DEBUG IS ON
    )

    .\dxil-spirv\dxil-spirv.exe "%bin2hlslInput%" --output "%bin2hlslInput%".tmp

    if defined bin2hlslOutput      .\spirv-cross\spirv-cross.exe "%bin2hlslInput%".tmp --hlsl --shader-model 66 > "%bin2hlslOutput%"
    if not defined bin2hlslOutput  .\spirv-cross\spirv-cross.exe "%bin2hlslInput%".tmp --hlsl --shader-model 66
    del "%bin2hlslInput%".tmp

:end
    call :cleanup
    exit /B

:cleanup
    REM The cleanup