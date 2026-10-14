# Third-party notices

## miniaudio

HWcontrol2.0's native Audio Controller Studio device host uses [miniaudio](https://github.com/mackron/miniaudio), pinned to version 0.11.22 through CMake FetchContent. The project offers a choice of public-domain dedication or MIT No Attribution license; see the upstream [LICENSE file](https://github.com/mackron/miniaudio/blob/0.11.22/LICENSE) for the complete terms. The upstream project is maintained by David Reid.

miniaudio is fetched at build time and is not vendored into this repository. Distribution packages that bundle its compiled code must preserve applicable license notices and comply with the selected upstream license.
