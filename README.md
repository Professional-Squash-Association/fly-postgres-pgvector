# fly-postgres-pgvector

Fly.io's `postgres-flex` image with [pgvector](https://github.com/pgvector/pgvector) built in.

```
ghcr.io/professional-squash-association/fly-postgres-pgvector:17.7-pgv0.8.5
```

PostgreSQL 17.10, pgvector 0.8.5, `linux/amd64`. Public, pulls without auth.

## Why

You can't add an extension to a Fly Postgres cluster after it exists. The `.so`
and control files have to be in the image you created the cluster from. On a
stock cluster you get:

```
ERROR: could not open extension control file
".../share/postgresql/17/extension/vector.control": No such file or directory
```

That's a missing file, not a missing privilege. `fly postgres attach` passes
`--superuser` by default, so your role can already run `CREATE EXTENSION`.
Easy hour to lose.

There's also no way to move a running cluster onto a different image lineage.
Get this wrong and the fix is a new cluster plus `fly postgres import`.

## Usage

```bash
fly postgres create --name your-db --region lhr \
  --image-ref ghcr.io/professional-squash-association/fly-postgres-pgvector:17.7-pgv0.8.5

fly postgres attach --app your-app your-db
```

```sql
CREATE EXTENSION vector;
```

`fly pg` commands still work. It's postgres-flex plus one extension, not a fork.

## Check it worked

Build an index, don't just create the extension. Index support is what breaks
when the build is subtly wrong, and you'd rather know now than during a schema
load:

```sql
CREATE TABLE _t (e vector(1536));
CREATE INDEX ON _t USING hnsw (e vector_cosine_ops);
DROP TABLE _t;
```

## Building your own

```bash
docker buildx build --platform linux/amd64 \
  --build-arg PGVECTOR_VERSION=0.8.5 \
  -t ghcr.io/YOUR-ORG/fly-postgres-pgvector:17.7-pgv0.8.5 \
  --push .
```

`--platform linux/amd64` matters. Fly VMs are amd64; on Apple Silicon you'll
build arm64, push it happily, and watch it fail to boot.

Changing the Postgres major version means changing `FROM` *and*
`postgresql-server-dev-NN`. Miss the second and the build passes while the
extension lands somewhere Postgres won't look.

### Pushing to GHCR

`gh auth token` doesn't carry `write:packages`, so you get:

```
denied: permission_denied: The token provided does not match expected scopes
```

```bash
gh auth refresh -h github.com -s write:packages
gh auth token | docker login ghcr.io -u YOUR-USERNAME --password-stdin
```

New packages are private and `fly postgres create` pulls anonymously. Make it
public first, or you'll debug a pull error that never mentions visibility. If
the package is linked to a repo you have to drop the inherited permissions
before the visibility setting shows up.

## Caveats

**Patching is yours now.** `fly image update` resolves against your registry,
not Fly's, so it only ever finds tags you pushed. Nothing tells you when a
Postgres security release lands. Watch
[flyio/postgres-flex tags](https://hub.docker.com/r/flyio/postgres-flex/tags)
and rebuild:

```bash
docker buildx build --platform linux/amd64 \
  -t ghcr.io/YOUR-ORG/fly-postgres-pgvector:17.8-pgv0.8.5 --push .

fly image update --image ghcr.io/YOUR-ORG/fly-postgres-pgvector:17.8-pgv0.8.5 -a your-db
```

Minors are binary compatible, so that's a rolling restart with no dump. Pushing
a tag runs [the build workflow](.github/workflows/build.yml) if you'd rather
not do it locally.

**The tag isn't the Postgres version.** `flyio/postgres-flex:17.7` ships
PostgreSQL 17.10. Don't read it against postgresql.org's table and conclude
you're behind:

```bash
docker run --rm flyio/postgres-flex:17.7 postgres --version
```

**Major upgrades are migrations.** Fly has no in-place major upgrade. It's a
new cluster and `fly postgres import`, with downtime, and HNSW indexes get
rebuilt during the restore — on a large table that's most of the outage.

Which is why the EOL date is worth picking on deliberately.
[PG 17 runs to Nov 2029, PG 16 to Nov 2028](https://www.postgresql.org/support/versioning/).
Bumping the base tag before the cluster exists is one line. After, it's a
weekend.

## Use Managed Postgres instead, if you can

pgvector is a checkbox on [MPG](https://fly.io/docs/mpg/) and Fly patches it
for you. None of the above applies.

We're not on it because MPG's user isn't a superuser, which seems to rule out
the extra databases Solid Cache and Solid Queue want alongside the primary. On
a single database, use MPG.

## Updating pgvector

```bash
docker buildx build --platform linux/amd64 \
  --build-arg PGVECTOR_VERSION=0.9.0 \
  -t ghcr.io/YOUR-ORG/fly-postgres-pgvector:17.7-pgv0.9.0 --push .

fly image update --image ghcr.io/YOUR-ORG/fly-postgres-pgvector:17.7-pgv0.9.0 -a your-db
```

```sql
ALTER EXTENSION vector UPDATE;
```

Read pgvector's changelog first. Index format changes mean a reindex.

## Tags

`<fly-image-version>-pgv<pgvector-version>`, e.g. `17.7-pgv0.8.5`. There's no
`latest` — pinning your database image is the whole point.

## Licence

MIT. [pgvector](https://github.com/pgvector/pgvector) is PostgreSQL-licensed
and [postgres-flex](https://github.com/fly-apps/postgres-flex) is Fly's; both
keep their own terms.
