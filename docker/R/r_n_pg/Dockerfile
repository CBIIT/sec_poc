

FROM postgres:17
#RUN dnf install -y postgresql17
#RUN dnf install postgresql17-server
#RUN /usr/pgsql-17/bin/postgresql-17-setup initdb
#RUN systemctl start postgresql-17
COPY files/init.sql /docker-entrypoint-initdb.d/
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
COPY files/.Rprofile ~/
COPY files/.Rprofile /root


#
RUN git clone https://github.com/abseil/abseil-cpp.git
WORKDIR /opt/R/sec_poc/abseil-cpp
RUN mkdir build
WORKDIR /opt/R/sec_poc/abseil-cpp/build
COPY files/CMakeLists.txt .
RUN cmake -DABSL_BUILD_TESTING=ON -DABSL_USE_GOOGLETEST_HEAD=ON -DCMAKE_CXX_STANDARD=17 ..
#RUN make -j


WORKDIR /opt/R/sec_poc
#               install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))

COPY files/quick-install-r-packages.R .
#RUN Rscript ./quick-install-r-packages.R
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))))'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("glue@1.7.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("cpp11@0.4.7", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("RSQLite@2.3.5", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("downlit@0.4.5", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("purrr@1.2.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("pkgdown@2.2.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("profvis@0.4.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("waldo@0.6.2", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("testthat@3.3.1", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("httr2@1.2.2", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("devtools@2.4.6", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("leaflet@2.2.3", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("maps@3.4.3", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinythemes@1.2.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinydashboard@0.7.3", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinyjs@2.1.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("sqldf@0.4-11", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinyWidgets@0.9.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("stringi@1.8.7", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("datawizard@1.3.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("sjmisc@2.8.11", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinyBS@0.63.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("collapsibleTree@0.1.8", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("lubridate@1.9.4", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinyFeedback@0.4.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("parsedate@1.3.2", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("reticulate@1.44.1", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("pool@1.0.4", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinyalert@3.1.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("RPostgres@1.4.8", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("stringr@1.6.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shinymanager@1.0.410", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("writexl@1.5.4", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("config@0.3.2", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("plyr@1.8.9", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("htmlwidgets@1.6.4", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("data.tree@1.2.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("dplyr@1.1.4", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("RColorBrewer@1.1-3", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("colorspace@2.1-2", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("httr@1.4.7", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("data.table@1.18.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("jsonlite@2.0.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("openxlsx@4.2.8.1", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("assertthat@0.2.1", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("shiny@1.12.1", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("DT@0.34.0", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("DBI@1.2.3", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("xtable@1.8-4", ask = FALSE)'
#RUN Rscript -e 'options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/latest/bin/linux/centos8-%s/%s", R.version["arch"], substr(getRversion(), 1, 3))));install.packages("gtable@0.3.6", ask = FALSE)'

RUN dnf install -y sudo && \
    groupadd --gid ${USERID} ${USERNAME} && \
    useradd --uid ${USERID} --gid ${USERNAME} --shell /bin/bash --create-home ${USERNAME} && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    chown -R ${USERNAME} /opt/R/${R_VERSION} && \
    chown -R ${USERNAME} /opt/R/sec_poc
#RUN sudo apt update
#RUN sudo apt install libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev libwebp-dev
#RUN sudo service postgresql start
#RUN psql postgres -c "create user sec with password 'sec'"
#RUN psql postgres -c "create database sec"
#RUN psql secapp -c "grant all privileges on database sec to sec"
USER ${USERNAME}
COPY files/.bashrc /home/${USERNAME}/.bashrc
COPY files/.zshrc /home/${USERNAME}/.zshrc
COPY files/init.sh .
RUN bash ./init.sh
USER root
RUN echo "root" | passwd "root" --stdin
CMD ["tail -f /dev/null"]