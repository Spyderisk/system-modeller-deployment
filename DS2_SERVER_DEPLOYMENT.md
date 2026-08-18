# DS2 Server Deployment

This branch assembles the DS2 System Modeller release without changing the
Spyderisk `dev`, `main`, project branches, or existing release tags.

## Release sequence

1. Push the `ds2-sdm` branches of `risk-report`, `system-modeller`, and
   `system-modeller-adaptor`.
2. Confirm the System Modeller and adaptor GitHub Actions workflows succeed.
3. Record the timestamped Docker image tags produced by those workflows in
   `DS2_COMPONENTS.yml` and `.env.ds2.example`. Do not deploy mutable
   `ds2-sdm-latest` tags as the final production release.
4. Push the `ds2-sdm` deployment branch after its reporting submodule points
   to the published `risk-report` commit and the immutable image tags have
   been recorded.
5. Create coordinated annotated release tags only after the server deployment
   has passed acceptance testing.

## Server prerequisites

- Linux host with Docker Engine and Docker Compose v2.
- Access to pull `spyderisk/system-modeller` and
  `spyderisk/system-modeller-adaptor` images.
- Existing UoS HTTPS reverse proxy route for
  `ds2.it-innovation.soton.ac.uk`.
- External UoS Keycloak client configuration for System Modeller.
- Exact HTTPS thin-client origins to place in `FRAME_ANCESTORS`.

## Clean installation

Clone the deployment branch and its reporting submodule:

```bash
git clone --branch ds2-sdm --recurse-submodules \
  https://github.com/Spyderisk/system-modeller-deployment.git
cd system-modeller-deployment
```

Create the server environment file and replace every `REPLACE_ME` value:

```bash
cp .env.ds2.example .env
```

The reporting submodule must contain:

```text
reporting/security/risk-report.py
reporting/compliance/risk-report.py
reporting/domain-current/csv
```

The matching knowledgebase is already versioned at:

```text
knowledgebases/domain-network-DevMS-b246-filtered.zip
```

Validate the resolved Compose configuration before starting:

```bash
docker compose -f docker-compose_external_kc.yml config
```

Pull the pinned images and start the clean deployment:

```bash
docker compose -f docker-compose_external_kc.yml pull
docker compose -f docker-compose_external_kc.yml up -d
docker compose -f docker-compose_external_kc.yml ps
```

## Acceptance checks

1. Open `https://ds2.it-innovation.soton.ac.uk/system-modeller/` and complete
   the external Keycloak login.
2. Confirm the domain-model version in the GUI.
3. Create a model, validate it, and run risk calculation.
4. Confirm the report control is red before calculation and green afterward.
5. Generate security, compliance, and combined PDFs.
6. Confirm iframe responses contain the configured `frame-ancestors` policy
   and do not contain `X-Frame-Options: DENY`.
7. Restart the Compose project and repeat login and report access checks.

## Configuration ownership

The deployment contains no production credentials. Keycloak secrets and any
site-specific reverse-proxy configuration remain server-managed values and
must not be committed.

This repository configures Spyderisk to use its System Modeller client in the
UoS Keycloak. The `test-btn` client serves the external DS2 single sign-on
flow: it is registered in the central DS2 Keycloak, which is federated with
the UoS Keycloak. Its registration and the federation configuration are
external DS2/UoS infrastructure and are not created by this deployment.

The `test-btn` client is unrelated to allowing Spyderisk to be displayed in an
iframe. From the Spyderisk application perspective, iframe execution introduces
no separate authentication feature and is outside the scope of the System
Modeller and adaptor changes in this release.
