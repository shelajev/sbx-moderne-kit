# Testing Plan

This plan assumes commands run on the host, not inside the current development sandbox, with Docker and `sbx` installed.

## Goals

- Verify the kit validates as an SBX kit.
- Verify sandbox creation installs `mod`.
- Verify the guessed network allowlist is sufficient for install and basic Moderne CLI calls.
- Verify proxy-managed Moderne auth works, or capture the exact failure mode.

## Prerequisites

```bash
sbx version
docker version
sbx secret set -g moderne
```

Paste a valid Moderne access token when prompted. Moderne access tokens usually look like `mat-...`.

## 1. Validate the kit

```bash
cd /Users/shelajev/ai-contrib/kits/moderne
sbx kit validate .
sbx kit inspect .
rm -rf /tmp/moderne-sbx-kit-stage
mkdir -p /tmp/moderne-sbx-kit-stage
rsync -a \
  --exclude .git \
  --exclude .github \
  --exclude .DS_Store \
  --exclude .env \
  --exclude .sbx \
  --exclude '*.tar' \
  --exclude '*.zip' \
  --exclude scripts \
  --exclude tmp \
  --exclude .tmp \
  ./ /tmp/moderne-sbx-kit-stage/
sbx kit pack /tmp/moderne-sbx-kit-stage -o /tmp/moderne-sbx-kit.zip
sbx kit validate /tmp/moderne-sbx-kit.zip
```

Expected:

- Validation succeeds.
- Inspect shows `kind: mixin`, `name: moderne`, proxy-managed `MODERNE_TOKEN`, and the expected network domains.
- Current SBX versions may warn that the v1 credential/network fields are deprecated; warnings are acceptable if validation still reports `VALID`.

If validation fails, fix `spec.yaml` before testing runtime behavior.

Do not use local `sbx kit push .` when `.env` or other local-only files are present. `sbx kit push` does not apply `.gitignore`; use the staged copy above or `scripts/push-kits.sh`.

## 2. Create a fresh sandbox

Use a fresh name for each clean install test so install commands rerun.

```bash
sbx create --name moderne-test-1 --kit . claude .
```

Expected:

- The Moderne CLI installer downloads from Maven Central.
- `mod` installs to `~/.moderne/cli/bin/mod`.
- Startup may attempt token login.

Watch the host-side SBX logs for denied domains. If install fails on download, likely missing domains include one of:

- `repo1.maven.org`
- `repo.maven.apache.org`

Add the concrete denied host to `network.allowedDomains` and retry with a new sandbox name.

## 3. Verify CLI install

```bash
sbx exec moderne-test-1 -- sh -lc 'which mod; mod --version; mod --help | sed -n "1,80p"'
```

Expected:

- `which mod` points to `/home/.../.moderne/cli/bin/mod`.
- `mod --version` prints a Moderne CLI version.
- Help text prints without auth.

If `mod` is missing, inspect install logs and confirm the Maven installer completed as user `1000`.

On Linux arm64, also check:

```bash
sbx exec moderne-test-1 -- sh -lc 'uname -m; java -version; test ! -d "$HOME/.moderne/cli/dist/jre"'
```

Expected:

- `uname -m` may be `aarch64`.
- Java 25+ is available on `PATH`.
- The bundled x86-64 JRE is absent so `mod` uses the sandbox JDK.

## 4. Test automatic auth

```bash
sbx exec moderne-test-1 -- sh -lc 'mod config moderne show'
```

Expected:

- The configured tenant is shown for `https://app.moderne.io` with API host `https://api.app.moderne.io`.
- Startup login either succeeds silently or the startup log captures the exact auth failure.

Possible failures:

- `401` or invalid token: confirm the host secret is correct with `sbx secret set -g moderne`, then recreate the sandbox.
- Proxy-managed sentinel is stored literally: the CLI may persist `proxy-managed` and later send it somewhere the SBX proxy does not rewrite. Capture the config file location and request URL from logs.
- Unknown domain denied: add the denied Moderne host to `network.allowedDomains`; if it is an API or auth host, also consider `serviceDomains`.

Useful inspection commands:

```bash
sbx exec moderne-test-1 -- sh -lc 'find "$HOME/.moderne" -maxdepth 4 -type f -print'
sbx exec moderne-test-1 -- sh -lc 'mod config moderne --help'
sbx exec moderne-test-1 -- sh -lc 'mod config --help'
```

Do not paste real token values into issue notes or commits.

## 5. Test manual auth fallback

If automatic auth fails, attach interactively:

```bash
sbx run --kit . moderne-test-1
```

Inside the sandbox:

```bash
mod config moderne login
mod config moderne show
```

Expected:

- The CLI documents whether browser auth, token auth, or another flow is required.
- Credentials persist across `sbx run` restarts if stored under the sandbox home directory.

Record:

- Exact prompts.
- Exact config files written under `~/.moderne`.
- Any additional network denials.

## 6. Exercise a low-risk Moderne command

After auth validates, run a read-only command that reaches Moderne APIs.

Start with command discovery:

```bash
sbx exec moderne-test-1 -- sh -lc 'mod --help'
sbx exec moderne-test-1 -- sh -lc 'mod config moderne --help'
```

Then choose the least destructive read-only command available, such as listing config, organizations, recipes, or user identity.

Known-good authenticated read-only smoke command:

```bash
sbx exec moderne-test-1 -- sh -lc 'mod config moderne organizations show | sed -n "1,120p"'
```

Expected:

- The command succeeds without additional domain denials.

If denied domains appear, decide whether they are core Moderne domains or workflow-specific artifact/source domains before adding them.

## 7. Persistence test

```bash
sbx run --kit . moderne-test-1
sbx exec moderne-test-1 -- sh -lc 'mod config moderne show'
```

Expected:

- `mod` remains installed.
- Auth/config state remains available.

If auth disappears, determine whether startup login is failing or the CLI writes outside persistent home.

## 8. Cleanup

```bash
sbx delete moderne-test-1
```

Use fresh names like `moderne-test-2` after every `spec.yaml` network or install change to avoid stale install state.

## Fix Checklist

When debugging, update these files as needed:

- `spec.yaml`: install command, startup login, `allowedDomains`, `serviceDomains`, `serviceAuth`.
- `README.md`: quickstart, auth caveats, known required domains.
- `TESTING_PLAN.md`: any newly discovered required smoke-test command.

Before committing:

```bash
npx --yes js-yaml spec.yaml >/dev/null
npx --yes js-yaml .github/workflows/validate.yml >/dev/null
bash -n run.sh
sbx kit validate .
```
