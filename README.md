Automatic weekly build of [dawn][] WebGPU implementation for 64-bit Windows (x64 and arm64).

Build produces single `webgpu_dawn.dll` file that exports all public Dawn WebGPU C functions.
To use in your code - either load the `webgpu_dawn.dll` file dynamically or link to it via `webgpu_dawn.lib` import library.

Download binary build as zip archive from [latest release][] page.

To build locally run `build.cmd` batch file, make sure you have installed all necessary dependencies (see the beginning of file).

For small example of using Dawn in C see my [gist][].

[dawn]: https://dawn.googlesource.com/dawn/
[latest release]: https://github.com/mmozeiko/build-dawn/releases/latest
[gist]: https://gist.github.com/mmozeiko/4c68b91faff8b7026e8c5e44ff810b62
