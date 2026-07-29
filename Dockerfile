# Fly.io's postgres-flex image with pgvector compiled in.
#
# Fly's stock postgres-flex does not ship pgvector, and an extension cannot be
# added to a Fly Postgres cluster after it has been created - the extension
# files have to be present in the image the cluster is built from. So this
# adds them.
#
# Build for linux/amd64. Fly VMs are amd64; a Mac builds arm64 by default and
# the resulting image pushes fine, then fails to boot.
#
#   docker buildx build --platform linux/amd64 \
#     -t ghcr.io/professional-squash-association/fly-postgres-pgvector:17.7-pgv0.8.5 \
#     --push .
#
# Keep FROM and postgresql-server-dev-NN in step when changing the Postgres
# major version.

FROM flyio/postgres-flex:17.7

ARG PGVECTOR_VERSION=0.8.5

LABEL org.opencontainers.image.source="https://github.com/Professional-Squash-Association/fly-postgres-pgvector" \
      org.opencontainers.image.description="Fly.io postgres-flex with pgvector compiled in. PostgreSQL 17, pgvector ${PGVECTOR_VERSION}." \
      org.opencontainers.image.licenses="MIT"

# Build pgvector from source, then strip the toolchain back out so the final
# image stays close to the size of the base
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      git \
      ca-certificates \
      postgresql-server-dev-17 \
 && git clone --branch "v${PGVECTOR_VERSION}" --depth 1 \
      https://github.com/pgvector/pgvector.git /tmp/pgvector \
 && cd /tmp/pgvector \
 && make OPTFLAGS="" \
 && make install \
 && rm -rf /tmp/pgvector \
 && apt-get purge -y build-essential git postgresql-server-dev-17 \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
