FROM google/cloud-sdk:slim

RUN \
  DEBIAN_FRONTEND=noninteractive \
    apt update && apt install --assume-yes --no-install-recommends \
      gettext-base \
      git \
      kubectl \
      make \
      nmap \
      parallel \
      wget \
  \
  && rm -rf /var/lib/apt/lists/* \
  \
  && curl https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -Lo /usr/local/bin/jq \
  && chmod +x /usr/local/bin/jq
