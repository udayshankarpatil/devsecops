FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git postgresql-client bash-completion \
    && rm -rf /var/lib/apt/lists/*

# Pre-install all service dependencies as a cached image layer.
# Only re-runs when a pyproject.toml changes — no re-downloads on normal rebuilds.
# Empty src/ stubs satisfy setuptools' package discovery without needing real source.
COPY services/api/pyproject.toml /tmp/build/api/pyproject.toml
COPY services/ingest/pyproject.toml /tmp/build/ingest/pyproject.toml
COPY services/fetch/pyproject.toml /tmp/build/fetch/pyproject.toml
RUN mkdir -p /tmp/build/api/src/api /tmp/build/ingest/src/ingest /tmp/build/fetch/src/fetch \
 && pip install --no-cache-dir \
    '/tmp/build/api[dev]' \
    '/tmp/build/ingest[dev]' \
    '/tmp/build/fetch[dev]' \
    pre-commit

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
 && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
 && echo 'source /etc/bash_completion' >> /home/$USERNAME/.bashrc \
 && echo 'export HISTCONTROL=ignoredups:erasedups' >> /home/$USERNAME/.bashrc

USER $USERNAME
WORKDIR /workspace
