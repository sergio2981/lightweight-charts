#!/usr/bin/env node

/*
  Runs the unit test suites. It backs `pnpm test`, and exists because
  `node --test` receives the same glob patterns on every platform but only
  expands them where the shell does: on Windows the `**` patterns match
  nothing, the runner reports 0 tests, and the suite passes vacuously.

  Here the patterns are expanded by `glob` and the resulting paths are handed
  to the runner as literal arguments, so the same command finds the same tests
  on Linux, macOS, and Windows.
 */

import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { glob } from 'glob';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const PATTERNS = ['tests/unittests/**/*.spec.ts', 'packages/*/tests/unit/**/*.spec.ts'];

const SETUP = './tests/unittests/setup.units.mjs';

/**
 * The environment the runner needs on Windows. The plugin tests shell out to
 * `tar` with an absolute output path, and the first `tar` on a Git for Windows
 * PATH is GNU tar, which reads `C:\dir\file.tgz` as a `host:path` spec and
 * fails with "Cannot connect to C:". Putting `%SystemRoot%\System32` first
 * selects the bsdtar that ships with Windows, which takes the path literally.
 * Nothing else the tests spawn (`npm`, `pnpm`, `node`) lives in System32.
 */
function runnerEnv() {
	if (process.platform !== 'win32') {
		return process.env;
	}
	const system32 = path.join(process.env.SystemRoot ?? 'C:\\Windows', 'System32');
	const pathKey = Object.keys(process.env).find(key => key.toUpperCase() === 'PATH') ?? 'PATH';
	const current = process.env[pathKey] ?? '';
	return { ...process.env, [pathKey]: current === '' ? system32 : `${system32};${current}` };
}

function collectSpecs(patterns) {
	const specs = patterns
		.flatMap(pattern => glob.sync(pattern, { cwd: repoRoot, posix: true }))
		.sort();
	return [...new Set(specs)];
}

function main() {
	const specs = collectSpecs(PATTERNS);
	if (specs.length === 0) {
		console.error(`❌ No test files matched ${PATTERNS.join(', ')}.`);
		process.exit(1);
	}

	const args = ['--import', SETUP, '--test', ...specs];
	const child = spawn('esno', args, { cwd: repoRoot, stdio: 'inherit', shell: process.platform === 'win32', env: runnerEnv() });
	child.on('error', error => {
		console.error(`❌ Could not run esno: ${error.message}`);
		process.exit(1);
	});
	child.on('close', code => process.exit(code ?? 1));
}

main();
