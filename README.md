# Moderne CLI Docker Sandboxes Kit

Docker Sandboxes kit that installs the [Moderne CLI](https://docs.moderne.io/user-documentation/moderne-cli) (`mod`) and wires a host-stored Moderne access token into the sandbox through proxy-managed auth.

## Quick start

```bash
sbx secret set -g moderne
sbx run --kit docker.io/olegselajev241/sbx-moderne-kit:latest claude .
```

Paste your Moderne access token when prompted by `sbx secret set`. Moderne access tokens usually look like `mat-...`.

You can also run directly from GitHub before the Docker Hub artifact is published:

```bash
sbx run --kit git+https://github.com/shelajev/sbx-moderne-kit.git claude .
```

## Named sandbox

For a persistent sandbox you can reattach to:

```bash
sbx create --name moderne-current \
  --kit docker.io/olegselajev241/sbx-moderne-kit:latest claude .

sbx run moderne-current
```

For local development of this kit:

```bash
./run.sh moderne-current
```

## How it works

Install runs once when the sandbox is created:

- Downloads the latest Linux Moderne CLI installer from Maven Central.
- Installs `mod` into `~/.moderne/cli/bin`.
- Adds `~/.moderne/cli/bin` to `.bashrc`.
- On Linux arm64 sandboxes, removes the bundled x86-64 JRE when Java 25 is already available so the wrapper uses the sandbox JDK.

Startup runs each time the sandbox starts:

- Configures the default Moderne SaaS tenant with `mod config moderne edit https://app.moderne.io --api https://api.app.moderne.io`.
- Runs `mod config moderne login --with-token "$MODERNE_TOKEN"` when `MODERNE_TOKEN` is present.
- Appends a short usage hint to `CLAUDE.md` for Claude-based agents.

The kit declares a `moderne` service in `spec.yaml`. Docker Sandboxes reads your host-stored `moderne` secret and injects it as an `Authorization: Bearer <token>` header for requests to Moderne API hosts. Inside the sandbox, `MODERNE_TOKEN` is proxy-managed so the real token is not exposed directly to the agent.

## Smoke test

After creating a named sandbox:

```bash
sbx exec moderne-current -- sh -lc 'export PATH="$HOME/.moderne/cli/bin:$PATH"; mod --version && mod config moderne show'
```

If auth fails, attach interactively and inspect the CLI config:

```bash
sbx run moderne-current
mod config moderne login
mod config moderne show
```

## Publishing

The `Publish Kits` workflow publishes this kit to Docker Hub as:

```text
docker.io/olegselajev241/sbx-moderne-kit:latest
```

Set repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`, then run the workflow manually.

## Network policy

The kit allows the domains needed for the CLI download and the default Moderne SaaS tenant:

- `repo1.maven.org`
- `app.moderne.io`, `api.app.moderne.io`, `login.app.moderne.io`

It also allows common Java build and recipe artifact sources:

- `repo.maven.apache.org`, `repo1.maven.org`, `search.maven.org`
- `plugins.gradle.org`, `services.gradle.org`
- `raw.githubusercontent.com`

Real Moderne/OpenRewrite workflows may need additional hosts for your source repositories, artifact repositories, package registries, or enterprise Moderne tenant. Fork this kit and extend `network.allowedDomains` for those environments.

## Known rough edges

- The Moderne CLI Linux release is large, so first sandbox creation can take a while.
- On Linux arm64, the Maven Central installer initially includes an x86-64 JRE, so the kit removes it and relies on the sandbox Java 25 runtime.
- The proxy-managed token path is the best guess for non-interactive auth. If the CLI stores or sends the sentinel in a way that bypasses the SBX proxy injection, use interactive `mod config moderne login` in a persistent sandbox while we adjust the kit.
- Enterprise/self-hosted Moderne tenants likely need different `allowedDomains`, `serviceDomains`, and possibly a different startup login command.
