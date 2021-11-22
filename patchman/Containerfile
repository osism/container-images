ARG PYTHON_VERSION=3.9
FROM python:${PYTHON_VERSION}

ARG VERSION=latest

ENV TZ=UTC
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /wait

COPY files/local_settings.py /etc/patchman/local_settings.py
COPY files/requirements.txt /requirements.txt
COPY files/run.sh /run.sh
COPY files/fixtures.json /fixtures.json

# hadolint ignore=DL3018
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
      curl \
      git \
      python3-apt \
      python3-dev \
    && apt-get clean \
    && apt-get autoremove -y \
    && mkdir /configuration \
    && rm -rf \
      /var/lib/apt/lists/* \
      /var/tmp/* \
    && chmod +x /wait

RUN if [ $VERSION = "latest" ]; then git clone https://github.com/furlongm/patchman.git /repository; fi \
    && if [ $VERSION != "latest" ]; then git clone -b v$VERSION https://github.com/furlongm/patchman.git /repository; fi

# hadolint ignore=DL3013
RUN pip3 install --no-cache-dir --upgrade pip \
    && pip3 install --no-cache-dir -r /repository/requirements.txt \
    && pip3 install --no-cache-dir -r /requirements.txt \
    && pip3 install --no-cache-dir /repository \
    && ln -s /usr/lib/python3/dist-packages/*apt* /usr/local/lib/python3.9/site-packages

RUN useradd patchman \
    && chown patchman: /etc/patchman/local_settings.py \
    && mkdir -p /var/lib/patchman/db \
    && lib=$(python3 -c "import site; print(site.getsitepackages()[0])") \
    && mkdir -p "$lib/run/static" \
    && chown -R patchman: /var/lib/patchman "$lib/run/static"

RUN apt-get remove -y \
      git \
      python3-dev \
    && rm -rf /repository /requirements.txt

USER patchman
WORKDIR /

EXPOSE 8000

CMD ["sh", "-c", "/wait && /run.sh"]
HEALTHCHECK CMD curl --fail http://localhost:8000 || exit 1

LABEL "org.opencontainers.image.documentation"="https://docs.osism.tech" \
      "org.opencontainers.image.licenses"="ASL 2.0" \
      "org.opencontainers.image.source"="https://github.com/osism/container-image-patchman" \
      "org.opencontainers.image.url"="https://www.osism.tech" \
      "org.opencontainers.image.vendor"="OSISM GmbH"
