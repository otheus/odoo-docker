# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

FROM ubuntu:24.04 AS base_os

LABEL Maintainer="Otheus Shelling <otheus.shelling@bmg.gv.at>"

ARG RTL_SUPPORT_WANTED
ARG NOTOFU_SUPPORT_WANTED

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
# In ubuntu, other locales dont exist unless you install weighty "locales" package
ENV LANG=C.UTF-8

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf

RUN apt-get update ;\
    NOTO_FONTS="${NOTOFU_SUPPORT_WANTED}" ;\
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        ${NOTO_FONTS:+fonts-noto-cjk} \
        gnupg \
        libssl-dev \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils 


RUN \
    if [ -z "${TARGETARCH}" ]; then \
        TARGETARCH="$(dpkg --print-architecture)" ;\
    fi ;\
    WKHTMLTOPDF_VERSION="0.12.6.1-3" ;\
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64")  WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") \
              WKHTMLTOPDF_ARCH=ppc64el ;\
              WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    *)        false ;; \
    esac ;\
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.jammy_${WKHTMLTOPDF_ARCH}.deb ;\
    echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - ;\
    apt-get install -y --no-install-recommends ./wkhtmltox.deb ;\
    rm wkhtmltox.deb ;\
    true

# install latest postgresql-client --why latest?
RUN \
    apt-get update  ;\
    apt-get install --no-install-recommends -y postgresql-client ;\
    rm -f /etc/apt/sources.list.d/pgdg.list ;\
    true

## If node-less is needed
RUN \
    [[ ${RTL_SUPPORT_WANTED:-0} = 0 ]] && exit 0 ;\
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        npm \
        node-less ;\
    npm install -g rtlcss ;\
    true

###

FROM base_os AS odoo

# Install Odoo
ARG ODOO_RELEASE=20260305
ARG ODOO_SHA=b085e04780b300e662cd621bf7f7da7037214f30
ENV ODOO_VERSION=18.0

RUN \
    curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb ;\
    echo "${ODOO_SHA} odoo.deb" | sha1sum -c - ;\
    apt-get -y install --no-install-recommends ./odoo.deb ;\
    rm -rf odoo.deb 

# Cleanup
RUN rm -rf /var/lib/apt/lists/*

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY --chown=odoo:odoo --chmod=0600 ./odoo.conf /etc/odoo/odoo.conf

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN install -D -d -o odoo -g odoo -m 0755 /mnt/extra-addons

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC=/etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]

# CMD ["odoo"]
# ^-- no this is confusing. entrypoint.sh should assume you want to run odoo as a server
#     unless you provide arguments. But CMD would provide just "odoo", which will make
#     it impossible for entrypoint.sh to know how you really want to run it.
