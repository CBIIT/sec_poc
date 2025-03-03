FROM oraclelinux:8

ARG OPTIONALS="false"
VOLUME [ "/opt/R/sec_poc_workspace" ]
ENV USERNAME=sec
ENV USERID=1000
ENV R_VERSION=3.6.1

# Copy the yum repo file with ol8_baseos_latest, o18_appstream, o18_codereadybuilder and ol8_addons enabled.
# See https://docs.oracle.com/en/database/oracle/machine-learning/oml4r/2.0.0/oread/install-oracle-r-distribution-oracle-linux-8-using-yum-or-dnf.html
# Also includes EPEL for geospatial development libraries
COPY files/oracle-linux-ol8.repo /etc/yum.repos.d/

RUN dnf install -y sudo
RUN groupadd --gid ${USERID} ${USERNAME} && useradd --uid ${USERID} --gid ${USERNAME} --shell /bin/bash --create-home ${USERNAME}
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER root
# Install necessary packages for building and running R
# See https://docs.posit.co/resources/install-r-source.html
RUN dnf builddep -y R; dnf install -y make java-21-openjdk-headless libxml2-devel openssl-devel git libpq-devel
# For leaflet, geospatial libraries
RUN dnf install gdal-devel proj-devel geos-devel sqlite-devel udunits2-devel 
# Optional development packages
RUN [ "${OPTIONALS}" = "true" ] && dnf install -y 'dnf-command(config-manager)'; dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo; dnf install -y gh --repo gh-cli
# vscode dev container can't run without it
RUN /sbin/ldconfig

USER ${USERNAME}
WORKDIR /home/${USERNAME}
ADD https://cran.rstudio.com/src/base/R-3/R-${R_VERSION}.tar.gz .
RUN sudo tar -xzvf R-${R_VERSION}.tar.gz
WORKDIR /home/${USERNAME}/R-${R_VERSION}
RUN sudo ./configure --prefix=/opt/R/${R_VERSION} --enable-R-shlib --enable-memory-profiling
RUN sudo make; sudo make install
RUN /opt/R/${R_VERSION}/bin/R --version
RUN sudo ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R; sudo ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript
RUN R --version 

USER root
WORKDIR /opt/R/sec_poc_workspace
RUN Rscript -e 'install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))'

COPY files/install_deps.pak.R .
RUN Rscript install_deps.pak.R

RUN chown -R ${USERNAME} /opt/R/${R_VERSION}

USER ${USERNAME}
COPY files/.bashrc /home/${USERNAME}/.bashrc
COPY files/.zshrc /home/${USERNAME}/.zshrc
WORKDIR /opt/R/sec_poc_workspace

CMD ["tail", "-f", "/dev/null"]
