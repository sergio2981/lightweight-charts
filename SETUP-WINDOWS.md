# Setting up on Windows

The documented workflow ([BUILDING.md](./BUILDING.md)) assumes a POSIX shell: it is what CI runs, and a few scripts in the repository rely on POSIX behaviour. This file is the Windows equivalent, plus the changes a clean checkout needs before any of it runs.

Nothing here is upstreamed: the Linux workflow is untouched. It is a local setup guide.

## Requirements

- NodeJS 22.3 or newer (`engines.node` in the root `package.json`)
- [pnpm](https://pnpm.io/) at the version pinned in the `packageManager` field, provided by [Corepack](https://nodejs.io/api/corepack.html)
- Git for Windows, which supplies the shell used below

Verify the tools before starting:

```bash
node --version
pnpm --version
```

## Install

```bash
git clone https://github.com/tradingview/lightweight-charts.git
cd lightweight-charts
corepack enable
pnpm install
pnpm exec puppeteer browsers install chrome
```

The last command is only needed for the e2e suites (`pnpm e2e:*`). It downloads Chrome into `.cache/puppeteer/` in the repository.

pnpm may report `Ignored build scripts: @swc/core, esbuild, memlab, ...`. That is expected: both `esbuild` and `@swc/core` ship prebuilt binaries as optional dependencies, so nothing breaks. Approve the scripts only if a package turns out to need its `install` step.

## Build

Two builds are needed before the test suite and the website will run:

```bash
pnpm build:prod
pnpm build:toolkit
```

- `pnpm build:prod` writes `dist/`. The plugin unit tests and the website pages import `lightweight-charts` through its package exports, which point at built output, so they cannot resolve anything until this has run.
- `pnpm build:toolkit` writes `packages/lwc-toolkit/dist/`, needed by the plugin packages that import `@tradingview/lwc-toolkit`.

`pnpm build` alone is not enough: it produces only the development bundles, while `dist/lightweight-charts.production.mjs` is what the exports map resolves to.

## Test

```bash
pnpm test
```

On a correctly set-up checkout this reports 684 passing tests. See [Patches](#patches) for why the script behind it is not the one upstream ships.

## Website

The website is a [Docusaurus](https://docusaurus.io/) build. Compile it once:

```bash
pnpm --filter lightweight-charts-website build
```

After that, serve it without rebuilding:

```bash
pnpm serve-website
```

`serve-website` reproduces the way GitHub Pages serves the site, including the `/lightweight-charts/` base path and the `trailingSlash: false` behaviour that makes the framed plugin previews resolve their assets. The URL is <http://localhost:3010/lightweight-charts/>.

If the port is taken, the server exits with a message; pick another by passing `--port` to `node scripts/serve-website.mjs`.

### Desktop shortcuts

`open-website.cmd` wraps the two commands above: it builds the site if `website/build/` is missing, starts the server, waits for the port to accept connections, then opens the browser. If the server is already running it only opens the browser. Output from the server goes to its own minimised window, so a startup failure is visible there.

Two icons are generated for it:

```bash
powershell -ExecutionPolicy Bypass -File scripts/make-icon.ps1
powershell -ExecutionPolicy Bypass -File scripts/make-icon.ps1 -OutPath scripts/lwc-demo.ico -Palette "45,26,14,240,160,32" -ShowVolume
powershell -ExecutionPolicy Bypass -File scripts/install-desktop-shortcut.ps1
```

The first command writes `scripts/lwc.ico` for the website, the second a distinct icon for the candle demo, and the third creates `Lightweight Charts.lnk` and `Lightweight Charts - Demo.lnk` on the desktop. Both `.ico` files hold seven sizes from 16 to 256 pixels, as 32-bit BMP entries rather than PNG entries, because the PNG form is unreadable to `System.Drawing.Icon`.

## Patches

A clean checkout fails on Windows in five places. Each is a platform difference rather than a defect in the scripts.

### 1. `pnpm test` reports zero tests

`node --test` is given `'./tests/unittests/**/*.spec.ts'` and expands it itself. On Windows those patterns match nothing, so the runner reports `tests 0, pass 0` and the suite passes without having run anything.

`scripts/run-unittests.mjs` expands the patterns with `glob` (already a dev dependency) and passes the resulting paths as literal arguments, which behaves the same on every platform. `package.json` points `test` at it and keeps the original command as `test:glob`.

The same script prepends `%SystemRoot%\System32` to `PATH` when running on Windows. The plugin tests build tarballs with `tar -czf <absolute path>`, and the GNU tar that Git for Windows installs reads `C:\dir\file.tgz` as a `host:path` specification and fails with `Cannot connect to C:`. The bsdtar that ships with Windows takes the path literally. Nothing else the tests launch (`node`, `npm`, `pnpm`) lives in `System32`, so the override is limited to that one tool.

### 2. `tar` in the plugin scripts

The same `host:path` problem affects three scripts that inspect published tarballs: `scripts/plugins/utils.mjs`, `scripts/plugins/catalogue-data.mjs` and `scripts/plugins/mock-registry.mjs`. `tarCommand()` in `utils.mjs` resolves the `System32` copy when it exists, and the three call sites use it.

### 3. `pnpm` cannot be spawned from Node

`scripts/plugins/build-demos.mjs` called `execFileSync('pnpm', …)`. On Windows pnpm is a `pnpm.cmd` shim, which gives `ENOENT` by bare name and `EINVAL` by full name, since Node stopped executing `.cmd` and `.bat` files without a shell. `runPnpm()` hands the invocation to the shell as a single command string on Windows. The arguments are fixed package filters with no spaces or shell metacharacters, so joining them is safe.

### 4. Paths from `URL.pathname`

`website/docusaurus.config.js` read `new URL('.', import.meta.url).pathname` in four places. On Windows that yields `/C:/Users/...`, and `path.resolve` turns it into `C:\C:\Users\...`, so the build failed with `ENOENT: mkdir 'C:\C:\…\website\.previous-typings-cache'`. All four now use `fileURLToPath`.

### 5. `execFileSync` cannot take a command string

Only relevant if you extend `open-website.cmd`: `execFileSync` requires an array of arguments, so a joined command string raises `The "args" argument must be of type object`. Use `spawnSync` with `shell: true`, or `execSync`. Batch files have the mirror-image trap — `%ERRORLEVEL%` inside a parenthesised block expands to the value from before the block ran, so use `if errorlevel 1`.

## Demo

`demo/index.html` is a self-contained page: candlesticks, a volume histogram and a 20-period moving average, driven by a seeded random walk with volatility clustering, plus range presets, a light/dark toggle and a live mode that updates the last candle every second. It loads `dist/lightweight-charts.standalone.production.js` directly and needs no server, but it does need `pnpm build:prod` to have run.

The data is generated in the browser from a fixed seed, so it is the same on every reload and needs no network access.
