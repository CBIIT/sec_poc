FROM oraclelinux:8

ARG OPTIONALS="false"
ENV R_VERSION=3.6.0
ENV USERNAME=sec
ENV USERID=1000
VOLUME [ "/opt/R/sec_poc_workspace" ]

RUN curl -L https://rstd.io/r-install > r-install.sh && \
    chmod u+x r-install.sh && \
    ./r-install.sh && \
    ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R && \
    ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript && \
    R --version

RUN dnf install -y epel-release && \
    dnf config-manager --enable ol8_codeready_builder && \
    dnf install -y \
    fontconfig-devel \
    freetype-devel \
    fribidi-devel \
    gdal-devel \
    geos-devel \
    harfbuzz-devel \
    libjpeg-devel \
    libpng-devel \
    libtiff-devel \
    libxml2-devel \
    openssl-devel \
    postgresql-devel \
    proj-devel \
    sqlite-devel && \
    dnf clean all

RUN if [ "${OPTIONALS}" = "true" ]; then \
    dnf install -y 'dnf-command(config-manager)' && \
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf install -y gh --repo gh-cli && \
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    dnf -qy module disable postgresql && \
    dnf install -y postgresql16; \
    fi

WORKDIR /opt/R/sec_poc_workspace
COPY files/install_deps.pak.R .
RUN Rscript -e 'install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))' && \
    Rscript install_deps.pak.R

RUN dnf install -y sudo && \
    groupadd --gid ${USERID} ${USERNAME} && \
    useradd --uid ${USERID} --gid ${USERNAME} --shell /bin/bash --create-home ${USERNAME} && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    chown -R ${USERNAME} /opt/R/${R_VERSION} && \
    chown -R ${USERNAME} /opt/R/sec_poc_workspace

USER ${USERNAME}
COPY files/.bashrc /home/${USERNAME}/.bashrc
COPY files/.zshrc /home/${USERNAME}/.zshrc

CMD ["R"]