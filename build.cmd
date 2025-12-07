@echo off
setlocal enabledelayedexpansion

cd %~dp0

rem
rem build architecture
rem

if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set HOST_ARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set HOST_ARCH=arm64
)

if "%1" equ "x64" (
  set TARGET_ARCH=x64
) else if "%1" equ "arm64" (
  set TARGET_ARCH=arm64
) else if "%1" neq "" (
  echo Unknown target "%1" architecture
  exit /b 1
) else (
  set TARGET_ARCH=%HOST_ARCH%
)

rem
rem dependencies
rem

where /q git.exe    || echo ERROR: "git.exe" not found    && exit /b 1
where /q cmake.exe  || echo ERROR: "cmake.exe" not found  && exit /b 1
where /q python.exe || echo ERROR: "python.exe" not found && exit /b 1

for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
if "%VS%" equ "" (
  echo ERROR: Visual Studio installation not found
  exit /b 1
)

rem
rem clone dawn
rem

if "%DAWN_COMMIT%" equ "" (
  for /f "tokens=1 usebackq" %%F IN (`git ls-remote https://dawn.googlesource.com/dawn HEAD`) do set DAWN_COMMIT=%%F
)

if not exist dawn (
  call git init dawn                                                    || exit /b 1
  call git -C dawn remote add origin https://dawn.googlesource.com/dawn || exit /b 1
)

call git -C dawn fetch --no-recurse-submodules origin %DAWN_COMMIT% || exit /b 1
call git -C dawn reset --hard FETCH_HEAD                            || exit /b 1

if exist dawn\third_party\dxc call git -C dawn\third_party\dxc reset --hard HEAD || exit /b 1

rem
rem fetch dependencies
rem

call python "dawn/tools/fetch_dawn_dependencies.py" --directory dawn

rem
rem patches
rem

rem call git apply -p1 --directory=dawn                 patches/dawn-no-onecore-apiset-lib.patch || exit /b 1
call git apply -p1 --directory=dawn                 patches/dawn-static-dxc-lib.patch        || exit /b 1
call git apply -p1 --directory=dawn/third_party/dxc patches/dxc-static-build.patch           || exit /b 1

rem
rem configure dawn build
rem

cmake.exe                                     ^
  -S dawn                                     ^
  -B dawn.build-%TARGET_ARCH%                 ^
  -A %TARGET_ARCH%                            ^
  -D CMAKE_BUILD_TYPE=Release                 ^
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -D CMAKE_POLICY_DEFAULT_CMP0092=NEW         ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -D ABSL_MSVC_STATIC_RUNTIME=ON              ^
  -D DAWN_BUILD_SAMPLES=OFF                   ^
  -D DAWN_BUILD_TESTS=OFF                     ^
  -D DAWN_ENABLE_D3D12=ON                     ^
  -D DAWN_ENABLE_D3D11=OFF                    ^
  -D DAWN_ENABLE_NULL=OFF                     ^
  -D DAWN_ENABLE_DESKTOP_GL=OFF               ^
  -D DAWN_ENABLE_OPENGLES=OFF                 ^
  -D DAWN_ENABLE_VULKAN=OFF                   ^
  -D DAWN_USE_GLFW=OFF                        ^
  -D DAWN_ENABLE_SPIRV_VALIDATION=OFF         ^
  -D DAWN_DXC_ENABLE_ASSERTS_IN_NDEBUG=OFF    ^
  -D DAWN_USE_BUILT_DXC=ON                    ^
  -D DAWN_FETCH_DEPENDENCIES=OFF              ^
  -D DAWN_BUILD_MONOLITHIC_LIBRARY=SHARED     ^
  -D TINT_BUILD_TESTS=OFF                     ^
  -D TINT_BUILD_SPV_READER=ON                 ^
  -D TINT_BUILD_SPV_WRITER=ON                 ^
  -D TINT_BUILD_CMD_TOOLS=ON                  ^
  || exit /b 1


if "%HOST_ARCH%" neq "%TARGET_ARCH%" (

  rem
  rem build native architecture tblgen executables for dxc
  rem

  cmake.exe                                ^
    -S dawn\third_party\dxc                ^
    -B dawn.build-%TARGET_ARCH%\dxc-native ^
    -A %HOST_ARCH%                         ^
    -D CMAKE_BUILD_TYPE=Release            ^
    -D BUILD_SHARED_LIBS=OFF               ^
    -D LLVM_TARGETS_TO_BUILD=None          ^
    -D LLVM_ENABLE_WARNINGS=OFF            ^
    -D LLVM_ENABLE_EH=ON                   ^
    -D LLVM_ENABLE_RTTI=ON                 ^
    || exit /b 1


  rem first build target architecture tblgen exe's
  cmake.exe --build dawn.build-%TARGET_ARCH% --config Release --target llvm-tblgen clang-tblgen || exit /b 1

  rem then build host architecture tblgen's
  cmake.exe --build dawn.build-%TARGET_ARCH%\dxc-native --config Release --target llvm-tblgen clang-tblgen || exit /b 1

  rem move host arch exe's (newer timestamp) over target arch exe's (older timestamp)
  rem so next dawn build steps will be able to use these exe's for different target arch
  move /y dawn.build-%TARGET_ARCH%\dxc-native\Release\bin\llvm-tblgen.exe  dawn.build-%TARGET_ARCH%\third_party\dxc\Release\bin\llvm-tblgen.exe
  move /y dawn.build-%TARGET_ARCH%\dxc-native\Release\bin\clang-tblgen.exe dawn.build-%TARGET_ARCH%\third_party\dxc\Release\bin\clang-tblgen.exe
)

rem
rem run the full dawn build
rem

set CL=/Wv:18
cmake.exe --build dawn.build-%TARGET_ARCH% --config Release --target webgpu_dawn tint_cmd_tint_cmd --parallel || exit /b 1

rem
rem prepare output folder
rem

mkdir dawn-%TARGET_ARCH%

echo %DAWN_COMMIT% > dawn-%TARGET_ARCH%\commit.txt

copy /y dawn.build-%TARGET_ARCH%\gen\include\dawn\webgpu.h               dawn-%TARGET_ARCH% || exit /b 1
copy /y dawn.build-%TARGET_ARCH%\Release\webgpu_dawn.dll                 dawn-%TARGET_ARCH% || exit /b 1
copy /y dawn.build-%TARGET_ARCH%\Release\tint.exe                        dawn-%TARGET_ARCH% || exit /b 1
copy /y dawn.build-%TARGET_ARCH%\src\dawn\native\Release\webgpu_dawn.lib dawn-%TARGET_ARCH% || exit /b 1

rem
rem Done!
rem

if "%GITHUB_WORKFLOW%" neq "" (

  rem
  rem GitHub actions stuff
  rem

  tar.exe -cavf dawn-%TARGET_ARCH%-%BUILD_DATE%.zip dawn-%TARGET_ARCH% || exit /b 1
)
