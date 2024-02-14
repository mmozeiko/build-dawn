@echo off
setlocal enabledelayedexpansion

cd %~dp0

rem
rem Dependencies
rem

where /q cmake.exe || (
  echo ERROR: "cmake.exe" not found
  exit /b 1
)

rem
rem 7-Zip
rem

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

rem
rem MSVC environment
rem

where /Q cl.exe || (
  set __VSCMD_ARG_NO_LOGO=1
  for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
  if "!VS!" equ "" (
    echo ERROR: Visual Studio installation not found
    exit /b 1
  )  
  call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1
)

rem
rem get depot tools
rem

set PATH=%CD%\depot_tools;%PATH%
set DEPOT_TOOLS_WIN_TOOLCHAIN=0

if not exist depot_tools (
  call git clone --depth=1 --no-tags --single-branch https://chromium.googlesource.com/chromium/tools/depot_tools.git || exit /b 1
)


rem
rem clone dawn
rem

if not exist dawn (
  call git clone --depth=1 --no-tags --single-branch https://dawn.googlesource.com/dawn || exit /b 1
) else (
  cd dawn
  call git restore src\dawn\native\CMakeLists.txt
  call git pull --force --no-tags || exit /b 1
  cd ..
)

cd dawn
copy /y scripts\standalone.gclient .gclient
call gclient sync || exit /b 1
cd ..

type extra.cmake >> dawn\src\dawn\native\CMakeLists.txt

rem
rem build dawn
rem

cmake                                         ^
  -S dawn                                     ^
  -B dawn.build                               ^
  -D CMAKE_BUILD_TYPE=Release                 ^
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -D BUILD_SHARED_LIBS=OFF                    ^
  -D BUILD_SAMPLES=OFF                        ^
  -D DAWN_ENABLE_D3D12=ON                     ^
  -D DAWN_ENABLE_D3D11=OFF                    ^
  -D DAWN_ENABLE_NULL=OFF                     ^
  -D DAWN_ENABLE_DESKTOP_GL=OFF               ^
  -D DAWN_ENABLE_OPENGLES=OFF                 ^
  -D DAWN_ENABLE_VULKAN=ON                    ^
  -D DAWN_BUILD_SAMPLES=OFF                   ^
  -D TINT_BUILD_SAMPLES=OFF                   ^
  -D TINT_BUILD_DOCS=OFF                      ^
  -D TINT_BUILD_TESTS=OFF                     ^
  || exit /b 1

set CL=/Wv:18
cmake.exe --build dawn.build --config Release --target webgpu --parallel || exit /b 1

rem
rem GitHub actions stuff
rem

copy /y dawn.build\gen\include\dawn\webgpu.h          .
copy /y dawn.build\Release\webgpu.dll                 .
copy /y dawn.build\src\dawn\native\Release\webgpu.lib .

if "%GITHUB_WORKFLOW%" neq "" (

  set /p DAWN_COMMIT=<dawn\.git\refs\heads\main
  echo !DAWN_COMMIT! > dawn_commit.txt

  for /F "skip=1" %%D in ('WMIC OS GET LocalDateTime') do (set LDATE=%%D & goto :dateok)
  :dateok
  set BUILD_DATE=%LDATE:~0,4%-%LDATE:~4,2%-%LDATE:~6,2%

  %SZIP% a -y -mx=9 webgpu-%BUILD_DATE%.zip webgpu.dll webgpu.lib webgpu.h dawn_commit.txt || exit /b 1

  echo ::set-output name=DAWN_COMMIT::!DAWN_COMMIT!
  echo ::set-output name=BUILD_DATE::%BUILD_DATE%

)

rem
rem done!
rem

goto :eof
