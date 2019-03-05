FROM docker:18.09.2 AS static-docker-source

FROM debian:buster

ENV CLOUD_SDK_VERSION 189.0.0

RUN \
  DEBIAN_FRONTEND=noninteractive \
    apt update && apt install --assume-yes --no-install-recommends \
      apt-transport-https \
      bzip2 \
      ca-certificates \
      curl \
      gettext-base \
      git \
      gnupg \
      golang \
      lsb-release \
      make \
      nmap \
      nmap-common \
      openssh-client \
      parallel \
      wget \
      xmlstarlet \
  \
  && export CLOUD_SDK_REPO \
  && CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
  && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
  && bash -euxo pipefail -c "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - " \
  \
  && DEBIAN_FRONTEND=noninteractive \
       apt update && apt install --assume-yes --no-install-recommends \
         google-cloud-sdk=${CLOUD_SDK_VERSION}-0 \
         kubectl \
  \
  && rm -rf /var/lib/apt/lists/* \
  \
  && curl https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -Lo /usr/local/bin/jq \
  && chmod +x /usr/local/bin/jq \
  \
  && curl https://github.com/mikefarah/yq/releases/download/2.1.1/yq_linux_amd64 -Lo /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq \
  \
  && curl https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.2/kustomize_2.0.2_linux_amd64 -Lo /usr/local/bin/kustomize \
  && chmod +x /usr/local/bin/kustomize \
  \
   && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image && \
  ssh-keyscan -H github.com gitlab.com bitbucket.org >> /etc/ssh/ssh_known_hosts && \
  useradd -ms /bin/bash jenkins

RUN cd /opt/ \
  && git clone https://github.com/bats-core/bats-core.git \
  && cd bats-core \
  && git checkout v1.1.0 \
  && ./install.sh /usr/local

RUN cd $(mktemp -d) \
  && curl -sL https://github.com/digitalocean/doctl/releases/download/v1.13.0/doctl-1.13.0-linux-amd64.tar.gz \
    | tar -xzv \
  && mv doctl /usr/local/bin/ \
  && doctl version

SHELL ["/bin/bash", "-c"]
RUN set -euxo pipefail; cd /opt/ \
  && curl -L https://github.com/github/hub/releases/download/v2.6.0/hub-linux-amd64-2.6.0.tgz \
  | tar xzvf - \
  && ./hub-linux-amd64-*/install \
  && hub --version

RUN curl -o /bin/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator \
  && chmod +x /bin/aws-iam-authenticator

RUN curl -Lo /bin/notary https://github.com/theupdateframework/notary/releases/download/v0.6.1/notary-Linux-amd64 \
  && chmod +x /bin/notary

COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker

RUN \
    gcloud --version \
    && docker --version \
    && kubectl version --client
