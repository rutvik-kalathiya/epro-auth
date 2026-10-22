# epro-auth

Everything OpenFGA for [e:pro Portfolio](https://github.com/rutvik-kalathiya/e-pro-portfolio): the authorization model and the server that runs it on [Render](https://render.com) with Postgres. The app includes this repository as a git submodule at `epro-auth/` and calls the server over HTTPS with a pre-shared API key.

OpenFGA answers *what* a signed-in user may do. *Who* the user is (sign-in, passwords, sessions) is handled by the app itself.

| File | Purpose |
| --- | --- |
| `model.fga` | The authorization model: roles per organisational unit, inherited by measures (projects) and plan versions. Uploaded by the app's `scripts/openfga-setup.mjs` |
| `model.test.yaml` | Tests for the model (36 checks) |
| `Dockerfile` | Downloads the checksum-verified OpenFGA release binary into a small Alpine image |
| `entrypoint.sh` | Migrates the Postgres schema, then runs OpenFGA with pre-shared-key auth on `$PORT` |
| `render.yaml` | Render Blueprint: this web service plus its Postgres database (Frankfurt) |

The server refuses to start without `OPENFGA_AUTHN_PRESHARED_KEYS`, so the API is never public. `/healthz` stays open for Render's health check; every API call needs `Authorization: Bearer <key>`.

## The model

Roles are granted on an organisational unit (`org_unit:hv-construction`, …) and flow down to everything that belongs to it:

| Role on `org_unit` | Measures (`project`) | Plan version (`plan_version`) | Unit permissions |
| --- | --- | --- | --- |
| `portfolio_manager` | view, edit, edit budget | view, prioritise, edit schedule, release | all of the below |
| `budget_approver` | view, edit budget | view | approve budgets, view reports |
| `planner` | view, edit | view, edit schedule | plan measures, create scenarios, view reports |
| `viewer` | view | view | view reports |

An `admin` of the `organization` is portfolio manager of every unit in it. A measure's `owner` may edit that measure even without a unit role. The app asks for the `can_*` relations only, so roles can change here without touching app code.

Run the tests after changing the model:

```sh
docker run --rm -v "$PWD:/model" -w /model openfga/cli model test --tests model.test.yaml
# or, with the CLI installed (brew install openfga/tap/fga):
fga model test --tests model.test.yaml
```

## Deploy on Render

1. In Render: **New → Blueprint**, pick this repository (give Render's GitHub app access to it, since it is private). Render reads `render.yaml` and creates `epro-auth` and `epro-auth-db`.
2. When it is live, note the service URL (e.g. `https://epro-auth.onrender.com`) and copy the generated `OPENFGA_AUTHN_PRESHARED_KEYS` value from the service's **Environment** tab.

Commits that change only `model.fga`, `model.test.yaml` or this README do not redeploy the service.

## Connect the app

In the app repository (the parent of this submodule), create `.env.production` (git-ignored) with the production values:

```sh
MONGODB_URI=mongodb+srv://...            # Atlas
MONGODB_DB_NAME=epro_portfolio
FGA_API_URL=https://epro-auth.onrender.com
FGA_API_TOKEN=<OPENFGA_AUTHN_PRESHARED_KEYS from Render>
```

Then, from the app repository's root:

```sh
node --env-file=.env.production scripts/openfga-setup.mjs   # prints FGA_STORE_ID and FGA_MODEL_ID; add them to .env.production
node --env-file=.env.production scripts/seed-mongodb.mjs    # demo data and its OpenFGA relations
node --env-file=.env.production scripts/create-user.mjs <username> --role portfolio_manager --unit hv-construction
```

Finally set `MONGODB_*` and `FGA_*` in the app's hosting environment and redeploy.

After changing `model.fga`, commit it here, update the submodule pointer in the app, then run `openfga-setup.mjs` again with `FGA_STORE_ID` set and update `FGA_MODEL_ID` in `.env.production` and the hosting environment. The script skips the upload when the model is unchanged.

## Rotating the key

`OPENFGA_AUTHN_PRESHARED_KEYS` accepts several comma-separated keys. Add the new key next to the old one, update `FGA_API_TOKEN` in the app and redeploy, then remove the old key.
