ARG PYTHON_VERSION=3.7
FROM python:${PYTHON_VERSION}-alpine

ARG VERSION=yoga

ARG USER_ID=45000
ARG GROUP_ID=45000

COPY files/requirements.txt /requirements.txt

RUN apk add --no-cache \
      dumb-init \
      libstdc++ \
    && apk add --no-cache --virtual .build-deps \
      build-base \
      cargo \
      libffi-dev \
      openssl-dev \
      python3-dev \
      rust \
    && if [ $VERSION = "yoga" ]; then wget -P / -O requirements.tar.gz https://tarballs.opendev.org/openstack/requirements/requirements-master.tar.gz; fi \
    && if [ $VERSION != "yoga" ]; then wget -P / -O requirements.tar.gz https://tarballs.opendev.org/openstack/requirements/requirements-stable-${VERSION}.tar.gz; fi \
    && mkdir /requirements \
    && tar xzf /requirements.tar.gz -C /requirements --strip-components=1 \
    && rm -rf /requirements.tar.gz \
    && while read -r package; do \
         grep -q "$package" /requirements/upper-constraints.txt && \
         echo "$package" >> /packages.txt || true; \
       done < /requirements.txt \
    && pip3 --no-cache-dir install --upgrade pip \
    && pip3 --no-cache-dir install -c /requirements/upper-constraints.txt -r /packages.txt \
    && pip3 --no-cache-dir install -c /requirements/upper-constraints.txt ospurge \
    && rm -rf /requirements \
      /requirements.txt \
      /packages.txt \
    && apk del .build-deps \
    && openstack complete > /osc.bash_completion \
    && addgroup -g $GROUP_ID dragon \
    && adduser -D -u $USER_ID -G dragon dragon \
    && mkdir /configuration \
    && chown -R dragon: /configuration

USER dragon
WORKDIR /configuration

VOLUME ["/configuration"]

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["openstack"]

LABEL "org.opencontainers.image.documentation"="https://docs.osism.tech" \
      "org.opencontainers.image.licenses"="ASL 2.0" \
      "org.opencontainers.image.source"="https://github.com/osism/container-image-openstackclient" \
      "org.opencontainers.image.url"="https://www.osism.tech" \
      "org.opencontainers.image.vendor"="OSISM GmbH"
