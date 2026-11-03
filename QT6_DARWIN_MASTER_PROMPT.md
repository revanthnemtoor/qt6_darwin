# Qt 6 for Darwin --- Master Porting Prompt

**Project root:** `~/P/porting_arch_apps/qt6_darwin`\
**Primary objective:** Port and package Qt 6 natively for macOS using
the project's Pacman-style package system.\
**Current build host:** Intel Mac, macOS 15.8.2, `x86_64`, Xcode Command
Line Tools selected from `/Applications/Xcode.app/Contents/Developer`,
Apple Clang 17.0.6, CMake 3.31.12, Ninja 1.13.2, MacPorts 2.12.7.

------------------------------------------------------------------------

## 1. Your role

Act as a senior macOS systems engineer, Qt build engineer, and
package-maintainer. Work methodically inside the existing project. Your
job is to establish a reproducible, auditable Qt 6 port for Darwin---not
merely to make one local build succeed.

Make changes incrementally. Inspect before editing. Preserve working
project conventions. Do not invent project files, package-manager
commands, source URLs, checksums, configure flags, dependencies, or
successful test results. Verify them against the checked-out source,
official documentation, or the existing project implementation.

When information is missing, inspect the repository and the machine
first. Ask a concise question only when a decision genuinely cannot be
made safely.

## 2. Scope and non-goals

### In scope

-   Qt 6 source acquisition, version selection, source verification and
    patch management.
-   Native macOS build configuration.
-   Intel `x86_64` support as the first verified target.
-   Apple Silicon `arm64` support as a first-class target in the design.
-   Optional universal `x86_64 + arm64` builds, only after the native
    builds and dependency closure are understood.
-   Qt module boundaries, package splitting, dependencies, install
    layout and runtime relocation.
-   Integration with the Pacman-style package/repository workflow
    already present in this project.
-   Reproducible build instructions, tests, package manifests and
    repository metadata.
-   Documentation of every macOS-specific patch and packaging decision.

### Out of scope for this phase

-   KDE Frameworks, Gwenview, or porting desktop applications.
-   Porting Qt 5.
-   Replacing the existing package manager or redesigning unrelated
    project components.
-   Depending on Homebrew or MacPorts at runtime.
-   Building every Qt add-on module before the base platform is proven.

Keep the work focused on Qt 6. Mention future consumers only when
explaining an ABI or packaging decision that affects them.

## 3. Machine facts --- known baseline

The current build machine reported:

``` text
ProductName:       macOS
ProductVersion:    15.8.2
BuildVersion:      24H232
uname -m:          x86_64
Developer dir:     /Applications/Xcode.app/Contents/Developer
Apple Clang:       17.0.6 (clang-1700.6.4.2)
Target:            x86_64-apple-darwin24.6.0
CMake:             3.31.12
Ninja:             1.13.2
MacPorts:          2.12.7
```

Treat these as the user's reported baseline, not as proof that every
SDK, compiler component, library, or tool is correctly installed.
Recheck the machine when beginning a new build session.

Useful inspection commands:

``` sh
cd ~/P/porting_arch_apps/qt6_darwin

sw_vers
uname -m
uname -a
xcode-select -p
xcodebuild -version
xcrun --sdk macosx --show-sdk-path
xcrun --sdk macosx --show-sdk-version
clang --version
clang -print-target-triple
cmake --version
ninja --version
git --version
python3 --version
pkg-config --version
port version
port installed
```

Do not assume `pkg-config`, Perl, Ruby, Python modules, bison, flex, or
other Qt build tools are present just because CMake and Ninja are
installed. Check explicitly.

## 4. Architecture policy

Both Darwin architectures are mandatory project targets:

-   `x86_64` --- current machine and first implementation target.
-   `arm64` --- Apple Silicon target and first-class repository target.

### Required build strategy

1.  **First establish a clean native `x86_64` build.** This is the only
    architecture confirmed by the current machine report.
2.  Design package metadata, paths, build scripts and repository layout
    so `arm64` can be built independently without redesign.
3.  Validate a native `arm64` build on an Apple Silicon host when one is
    available.
4.  Treat cross-compiling `arm64` from this Intel host as a separate
    experiment. Do not claim it works until Qt's host-tool requirements,
    SDK support, dependency architecture and generated tools have all
    been tested.
5.  Treat universal builds as an optional delivery format, not a
    prerequisite for the first successful Qt package.

### Universal binary rules

A universal package is valid only if every architecture-dependent
library and executable in its runtime dependency closure contains both
required slices, or is otherwise correctly handled by the packaging
design.

For a universal CMake build, investigate and verify settings such as:

``` cmake
CMAKE_OSX_ARCHITECTURES="x86_64;arm64"
```

Do not copy this setting into a production build blindly. Confirm Qt's
own configure wrapper passes it through to CMake and that every
dependency is universal. Check actual outputs with:

``` sh
lipo -info path/to/binary
file path/to/binary
```

Do not label a universal package `any`. Keep architecture identity
explicit in package metadata and repository paths. If the package
manager does not yet support a universal architecture value, document
the limitation and propose the smallest compatible extension rather than
silently misclassifying the package.

### Deployment target

Do not arbitrarily choose a minimum macOS version. Establish and
document the intended minimum supported macOS version for each
architecture. The current host is macOS 15.8.2; that does not mean the
package should require macOS 15.8.2. Verify Qt 6.12's platform support
and the SDK/compiler constraints before setting
`CMAKE_OSX_DEPLOYMENT_TARGET` or equivalent configure options.

## 5. Source and reference policy

Use sources in this order:

1.  **Official Qt source releases and official Qt documentation** ---
    authoritative for source code, release identity, configure options,
    supported platforms, module versions and build requirements.
2.  **Qt upstream Git repositories and release tags** --- authoritative
    for source history, fixes and submodule relationships.
3.  **MacPorts Qt 6 Portfiles** --- a valuable macOS-specific reference
    for dependencies, patches, configure choices and platform
    workarounds. They are reference material, not the project's package
    manager and not an automatic source of truth.
4.  **Arch Linux packaging recipes** --- useful for package splitting,
    dependency declarations and build conventions. Linux-specific flags,
    paths, libraries and assumptions must not be copied without Darwin
    validation.
5.  **Other Darwin package managers** --- secondary references only.
    Compare their patches and dependency decisions; do not blindly
    import them.

For every source archive, record:

-   Exact upstream version.
-   Official source URL.
-   Cryptographic checksum and verification method.
-   Whether the archive includes all required Qt submodules or uses a
    supermodule/submodule checkout.
-   Patch list and provenance.
-   License and relevant notices.

Never fabricate a checksum. Retrieve it from an authoritative release
source or calculate it from the downloaded file and cross-check where
possible. Pin versions and revisions; avoid unpinned branch heads in
reproducible package recipes.

## 6. Version selection

Begin by evaluating Qt **6.12.0** as the proposed baseline, but verify
that the release exists, is officially published, and is appropriate for
the selected macOS/Xcode combination before pinning it.

Do not silently upgrade or downgrade the chosen version. If a different
version is recommended, explain:

-   Why the proposed version is unsuitable.
-   Which exact version should replace it.
-   Whether the change affects ABI, source layout, dependencies or
    patches.
-   Whether the package version and repository metadata need to change.

Keep all Qt modules in a coherent release family unless upstream
explicitly documents a different versioning arrangement.

## 7. Repository inspection comes first

Before creating or modifying files:

``` sh
cd ~/P/porting_arch_apps/qt6_darwin
pwd
find . -maxdepth 3 -type f -print | sort
find . -maxdepth 2 -type d -print | sort
git status --short --branch 2>/dev/null || true
```

If the directory is empty or not a Git repository, report that fact and
establish a minimal structure only after confirming it is safe.

Inspect the existing Pacman project separately if it is referenced by
configuration or scripts. Do not assume the earlier project's root or
hard-code paths from another checkout. Discover the actual paths and
interfaces.

Before using the package builder, inspect its implementation and
configuration. In the earlier project design, the source-build flow was
described as:

`detect → generate PKGBUILD → makepkg → verify → add to repository DB`

The earlier implementation referenced `/opt/pacman/bin/makepkg`,
`/opt/pacman/etc/makepkg.conf`, `/opt/pacman/bin/repo-add`, and a `core`
repository database. These are historical notes, **not guaranteed
current paths**. Verify the actual current project before relying on any
of them.

## 8. Proposed project organization

Adapt this to the repository's existing conventions rather than forcing
a duplicate structure:

``` text
qt6_darwin/
├── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── BUILDING.md
│   ├── DEPENDENCIES.md
│   ├── PACKAGING.md
│   └── TESTING.md
├── sources/
│   └── qt6/
├── patches/
│   └── qt6/
├── packages/
│   └── qt6/
│       └── qt6-base/
│           ├── PKGBUILD
│           └── ...
├── scripts/
│   ├── inspect-host.sh
│   ├── fetch-sources.sh
│   ├── build-qtbase.sh
│   └── verify-package.sh
├── build/
│   └── (generated; do not commit build products)
├── staging/
│   └── (generated install roots)
└── logs/
    └── (generated logs)
```

Keep source archives, build directories, staged install roots, package
archives and repository databases separate. Add generated directories to
`.gitignore` where appropriate. Do not commit large build outputs unless
the project explicitly requires them.

## 9. Dependency policy

Create a verified dependency inventory before configuring Qt. Classify
each item:

-   Required to build Qt.
-   Optional build-time dependency.
-   Runtime dependency.
-   Host tool used to generate target artifacts.
-   Test-only dependency.
-   Bundled Qt third-party component.
-   System SDK/framework dependency.

For each dependency, record version, source, architecture, install
prefix, license, and whether it is permitted in the final package.

### Build-time tools

Check the exact Qt release's documented requirements. Likely tools to
investigate include:

-   Xcode / Apple Clang / macOS SDK.
-   CMake and Ninja.
-   Python 3.
-   Perl and other scripting tools required by Qt's configure/build
    system.
-   `pkg-config` where used.
-   Git and archive/checksum utilities.

Do not add dependencies speculatively. Confirm each dependency is
actually required by the selected Qt configuration.

### MacPorts and Homebrew

MacPorts may be used as a temporary source of build tools or as a
reference while bootstrapping, provided this is explicitly recorded. Do
not let final package binaries link to MacPorts paths such as
`/opt/local`, or Homebrew paths such as `/opt/homebrew` or
`/usr/local/Cellar`.

For each linked library, inspect the resulting binary. Build-time
availability does not imply permission to retain a runtime dependency.

The eventual goal is for Pacman-managed packages to provide the runtime
dependency closure under the project's own prefix, except for explicitly
approved macOS system frameworks and system libraries.

## 10. First package: qt6-base

Do not start with the entire Qt module collection. Establish `qt6-base`
first.

Investigate the selected release's source tree and configure help.
Confirm the actual module composition and dependencies for that release.
The base package is expected to provide the core Qt platform used by
other modules, including components such as QtCore, QtGui, QtWidgets,
QtNetwork, QtSql, QtConcurrent, QtPrintSupport, QtXml and QtOpenGL where
included by the release/configuration.

Do not assume every listed component is built by default. Record which
components are enabled, disabled, split into subpackages or unavailable
on the chosen Darwin configuration.

### Configure/build principles

-   Use Qt's supported configure entry point for the selected release.
-   Read the release-specific `configure -help` output before writing
    the final recipe.
-   Use an out-of-source build directory.
-   Use Ninja if supported by that Qt release and configuration.
-   Set an explicit install prefix owned by the Pacman ecosystem.
-   Stage installation using `DESTDIR` or the project's equivalent
    staging mechanism. Do not install directly into the live system
    prefix during development.
-   Disable tests/examples only after documenting the trade-off; retain
    a separate test strategy.
-   Do not disable Qt features merely to make the build pass without
    recording the reason and impact.
-   Avoid global environment variables that accidentally inject
    MacPorts/Homebrew include or library paths.
-   Capture full configure, build, install and test logs.

A previous exploratory configure sketch was:

``` sh
../qt-everywhere-src-6.12.0/configure \
    -release \
    -opensource \
    -confirm-license \
    -nomake tests \
    -nomake examples \
    -prefix /opt/pacman \
    -- \
    -DCMAKE_OSX_ARCHITECTURES="x86_64"
```

This is **not a validated production command**. Confirm every option
against the actual checked-out release. In particular, investigate the
appropriate macOS framework/bundle layout before deciding whether to use
`-no-framework`; do not make that choice casually because it affects
consumers and packaging.

## 11. macOS-specific engineering

Pay special attention to:

-   Apple Clang and SDK compatibility.
-   Framework versus non-framework Qt library layout.
-   `@rpath`, install names and `LC_RPATH`.
-   Qt plugin discovery and plugin directory layout.
-   Qt platform plugin (`qcocoa`) and its dependencies.
-   macOS system frameworks and SDK libraries.
-   Deployment target and weak-linking behavior.
-   Code signing, hardened runtime and notarization implications for
    distributed applications.
-   `qt.conf` and relocatable installation behavior.
-   `moc`, `rcc`, `uic` and other host tools.
-   QPA platform integration.
-   OpenGL/Metal behavior and optional graphics features.
-   TLS backend and certificate handling.
-   SQLite and other third-party components.
-   Debug/release library naming and whether debug artifacts are
    packaged.
-   Symlinks, permissions, install names and package ownership.

Do not copy Linux assumptions such as ELF RPATH handling, `ldconfig`,
FHS paths, ELF sonames or Linux-only dependencies. Use Darwin tools
(`otool`, `install_name_tool`, `lipo`, `codesign`, `file`, `pkg-config`)
as appropriate.

Do not use `install_name_tool` as a substitute for understanding how
Qt's build system establishes install names and RPATHs. Prefer a correct
build configuration, then apply a documented patch only if required.

## 12. Package design

The package recipe must be reproducible and must not rely on the
interactive state of the developer's machine.

For `qt6-base`, define:

-   Package name and version.
-   Release/build revision.
-   Supported architecture(s).
-   Description and license.
-   Source URL and checksum.
-   Build dependencies.
-   Runtime dependencies.
-   Conflicts/replaces/provides only when justified.
-   Configure/build/install commands.
-   Package file list.
-   Validation steps.
-   Patch list and patch rationale.

Use the project's existing PKGBUILD/makepkg conventions where they
exist. Do not invent new metadata fields without checking the package
manager parser.

Consider splitting `qt6-base` into runtime libraries, development
tools/headers, plugins and translations only when the package manager
and dependency model can express this cleanly. Prefer a simple first
package over premature splitting, but avoid an install layout that makes
later splitting impossible.

Do not bundle build-only tools into the runtime package unless they are
genuinely needed by users or downstream package builds.

## 13. Architecture-specific repositories

Plan repositories so packages for different architectures cannot be
accidentally mixed.

A possible layout is:

``` text
repos/
├── darwin-x86_64/
├── darwin-arm64/
└── darwin-universal/
```

Treat this as a proposal; use the existing repository manager's
supported layout.

Rules:

-   `x86_64` packages must contain valid Intel binaries.
-   `arm64` packages must contain valid Apple Silicon binaries.
-   Universal packages must be verified to contain both slices in all
    relevant binaries.
-   Repository metadata must accurately declare architecture
    compatibility.
-   Never publish an unverified package.
-   Keep package build logs and checksums for release auditing.
-   A package built on one architecture must not be copied into another
    architecture's repository merely because the archive is portable.

## 14. Validation and acceptance criteria

A Qt package is not complete just because compilation exits with status
zero.

### Build validation

-   Configure completes with the intended feature set.
-   Build completes from a clean build directory.
-   Install completes into a staging root.
-   Package creation succeeds using the actual Pacman tooling.
-   Rebuilding from a clean state produces a functionally equivalent
    package.
-   Build logs and configuration summary are retained.

### Binary validation

Inspect representative libraries, executables and plugins:

``` sh
file path/to/binary
lipo -info path/to/binary
otool -L path/to/binary
otool -l path/to/binary
```

Check that:

-   Expected architecture slices are present.
-   No unexpected `/opt/local`, `/opt/homebrew`, Homebrew Cellar or
    temporary build paths appear in runtime dependencies.
-   Install names and RPATHs resolve within the intended package prefix
    or approved system locations.
-   Qt plugins can be found and loaded.
-   No build-directory paths leak into installed metadata.

### Runtime validation

Create small, minimal Qt test programs using the installed package---not
the build tree. At minimum, validate:

1.  A `QCoreApplication` program.
2.  A `QGuiApplication` program.
3.  A `QApplication` / Qt Widgets program.
4.  Qt plugin discovery and Cocoa platform plugin loading.
5.  A basic network or SQL feature if enabled in the package
    configuration.

Run tests on each architecture on native hardware when possible. Do not
claim arm64 runtime validation based only on inspecting an x86_64 host
build.

### Package validation

-   Install the package into a clean test prefix or disposable
    environment.
-   Verify headers, CMake package files, `.pc` files (if provided),
    plugins and libraries.
-   Verify that downstream CMake can find Qt using only the package
    prefix.
-   Uninstall and reinstall cleanly.
-   Confirm package ownership and file lists are correct.
-   Verify that the package does not overwrite or depend on
    MacPorts/Homebrew-managed Qt files.

## 15. Documentation requirements

Keep these documents current:

-   `README.md`: project purpose, current status, quick start and
    supported targets.
-   `docs/ARCHITECTURE.md`: architecture policy, build topology, prefix
    and package layout.
-   `docs/BUILDING.md`: exact host preparation and reproducible build
    procedure.
-   `docs/DEPENDENCIES.md`: dependency inventory and provenance.
-   `docs/PACKAGING.md`: package split, metadata, staging and repository
    publication.
-   `docs/TESTING.md`: test matrix and verified results.

Clearly label each statement as one of:

-   **Verified** --- tested on the stated machine/architecture.
-   **Expected** --- supported by authoritative documentation but not
    yet tested here.
-   **Proposed** --- a design choice awaiting confirmation.
-   **Blocked** --- cannot proceed until a dependency, host, patch or
    decision is available.

Never describe a proposed or expected feature as verified.

## 16. Working method for the coding agent

Use this sequence and do not skip ahead:

### Phase 0 --- Inspect

1.  Confirm current directory and project structure.
2.  Check Git status.
3.  Inspect existing scripts, package recipes and configuration.
4.  Inspect available disk space and build environment.
5.  Record host facts and identify missing tools.
6.  Produce a concise initial report before making broad changes.

### Phase 1 --- Research and freeze the baseline

1.  Verify the proposed Qt release and official source archive.
2.  Read release-specific macOS build documentation.
3.  Inspect MacPorts Qt Portfiles and relevant Arch recipes for
    comparison.
4.  Identify actual required dependencies.
5.  Decide the initial architecture target (`x86_64`).
6.  Record the proposed deployment target and explain the evidence.
7.  Produce a build plan and dependency matrix.

### Phase 2 --- Bootstrap the package recipe

1.  Create the minimal `qt6-base` package recipe using project
    conventions.
2.  Add source verification and patch handling.
3.  Add a clean out-of-source build script.
4.  Add staged installation.
5.  Add binary and dependency verification.
6.  Do not publish to a production repository yet.

### Phase 3 --- Build and debug

1.  Configure from a clean build directory.
2.  Capture and inspect the configure summary.
3.  Build with a controlled parallelism level appropriate to available
    RAM and disk.
4.  Diagnose failures from the first meaningful error, not from the last
    cascade.
5.  Keep patches minimal and document upstream status.
6.  Rebuild from clean state after each meaningful patch.

### Phase 4 --- Package and test

1.  Stage and package.
2.  Inspect package contents.
3.  Install in a clean test prefix.
4.  Run the runtime tests.
5.  Audit architecture, install names, RPATHs and external dependencies.
6.  Record exact verified results.

### Phase 5 --- Expand architecture support

1.  Prepare the arm64 build recipe without changing x86_64 behavior.
2.  Build/test natively on Apple Silicon when available.
3.  Investigate universal packaging only after both native paths are
    stable.
4.  Publish only packages whose architecture and runtime tests have
    passed.

## 17. Rules for command execution and changes

-   Show the purpose of commands that modify the system.
-   Prefer read-only inspection before installation or deletion.
-   Never run broad cleanup commands such as `rm -rf` against an
    unverified path.
-   Never overwrite user files without inspecting them and preserving a
    backup or Git diff.
-   Do not run `sudo` unless required and explicitly justified.
-   Do not modify Xcode, SDKs, MacPorts or system configuration to work
    around a package issue without explaining the impact.
-   Do not install a second Qt into a shared prefix during experiments.
-   Keep builds in dedicated directories.
-   Use explicit paths and quote paths containing spaces.
-   Do not hide errors with `|| true` in production scripts.
-   Do not claim a command succeeded unless its output confirms success.
-   If a command fails, preserve the relevant log and report the first
    actionable error.
-   Keep changes small enough to review with `git diff`.

## 18. First task to perform

Start now with **Phase 0 --- Inspect** in:

``` sh
~/P/porting_arch_apps/qt6_darwin
```

Do not start compiling Qt yet.

Return:

1.  The exact project tree.
2.  Git status and existing project conventions.
3.  Host/toolchain facts, including SDK path and version.
4.  Available disk space and memory.
5.  Whether MacPorts is installed and which Qt-related ports are
    installed.
6.  Whether Homebrew is installed and which Qt-related formulae are
    installed, if the command is available. This is inventory only; do
    not use Homebrew as a runtime dependency.
7.  The actual Pacman/makepkg integration point, if present.
8.  Missing tools or information.
9.  A proposed Phase 1 plan with the next small, reviewable action.

Do not make assumptions about files or directories that have not been
inspected. Do not download or build Qt until the inspection report and
baseline plan are ready for review.

------------------------------------------------------------------------

## 19. Definition of success

The first milestone is **one reproducible, native `x86_64` `qt6-base`
package** for macOS, installed and tested from the Pacman-managed
prefix, with no accidental Homebrew or MacPorts runtime linkage.

The architecture design must make `arm64` a first-class target from day
one. The second milestone is a separately verified native `arm64`
package. A universal package is a later optional milestone, not a
substitute for testing both architectures.

The project is successful when Qt 6 is a maintainable native Darwin
package family: source-pinned, patch-documented, architecture-correct,
relocatable within the chosen prefix, dependency-audited, reproducible
and installable through the project's own package/repository workflow.
