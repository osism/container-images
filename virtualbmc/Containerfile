ARG PYTHON_VERSION=3.9
FROM python:${PYTHON_VERSION}

ARG VERSION=2.2.0

ENV CRYPTOGRAPHY_DONT_BUILD_RUST=1

COPY files/run.sh /run.sh

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-dev libvirt-dev \
    && python3 -m pip --no-cache-dir install -U 'pip==21.1.3' \
    && python3 -m pip install --no-cache-dir virtualbmc==${VERSION} \
    && apt-get remove -y python3-dev libvirt-dev \
    && rm -rf /var/lib/apt/lists

CMD ["/run.sh"]

LABEL "org.opencontainers.image.documentation"="https://docs.osism.tech" \
      "org.opencontainers.image.licenses"="ASL 2.0" \
      "org.opencontainers.image.source"="https://github.com/osism/container-image-virtualbmc" \
      "org.opencontainers.image.url"="https://www.osism.tech" \
      "org.opencontainers.image.vendor"="OSISM GmbH"
