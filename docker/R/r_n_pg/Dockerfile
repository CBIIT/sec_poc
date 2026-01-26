

FROM postgres:17

COPY docker/R/files/init.sql /docker-entrypoint-initdb.d/
#USER postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=sec
RUN apt-get install -y curl \
    yum \
    lsof \
    ping

# Expose the default PostgreSQL port
EXPOSE 5432
#RUN echo "postgres" | passwd "postgres" --stdin
#
FROM oraclelinux:8

ARG OPTIONALS="true"
ENV R_VERSION=4.5.1
ENV USERNAME=sec
ENV USERID=1000

#
VOLUME [ "/opt/R/sec_poc" ]

RUN curl -L https://rstd.io/r-install > r-install.sh && \
    chmod u+x r-install.sh && \
    ./r-install.sh && \
    ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R && \
    ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript && \
    R --version

RUN dnf install -y git
RUN dnf install -y cmake
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
    sqlite-devel  \
    freetype-devel \
    libpng-devel \
    libtiff-devel \
    libjpeg-turbo-devel \
    libwebp-devel \
    udunits2-devel  \
    abseil-cpp-devel && \
    dnf clean all


RUN if [ "${OPTIONALS}" = "true" ]; then \
    dnf install -y 'dnf-command(config-manager)' && \
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf install -y gh --repo gh-cli --nobest && \
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    dnf -qy module disable postgresql; \
    fi

WORKDIR /opt/R/sec_poc
COPY docker/R/files/.Rprofile ~/
COPY docker/R/files/.Rprofile /root


#
RUN git clone https://github.com/abseil/abseil-cpp.git
WORKDIR /opt/R/sec_poc/abseil-cpp
RUN mkdir build
WORKDIR /opt/R/sec_poc/abseil-cpp/build
COPY docker/R/files/CMakeLists.txt .
RUN cmake -DABSL_BUILD_TESTING=ON -DABSL_USE_GOOGLETEST_HEAD=ON -DCMAKE_CXX_STANDARD=17 ..
#RUN make -j


WORKDIR /opt/R/sec_poc
#               install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))

COPY docker/R/files/quick-install-r-packages.R .

RUN dnf install -y sudo && \
    groupadd --gid ${USERID} ${USERNAME} && \
    useradd --uid ${USERID} --gid ${USERNAME} --shell /bin/bash --create-home ${USERNAME} && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    chown -R ${USERNAME} /opt/R/${R_VERSION} && \
    chown -R ${USERNAME} /opt/R/sec_poc

USER ${USERNAME}
COPY docker/R/files/.bashrc /home/${USERNAME}/.bashrc
COPY docker/R/files/.zshrc /home/${USERNAME}/.zshrc
COPY docker/R/files/init.sh .
RUN bash ./init.sh
USER root
RUN echo "root" | passwd "root" --stdin
COPY ../../renv.lock .
RUN Rscript -e "options(repos = c(CRAN = sprintf(\"https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s\", R.version[\"arch\"], substr(getRversion(), 1, 3))));install.packages(\"renv\")"
RUN Rscript -e "options(repos = c(CRAN = sprintf(\"https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s\", R.version[\"arch\"], substr(getRversion(), 1, 3))));renv::restore()"
CMD ["tail -f /dev/null"]