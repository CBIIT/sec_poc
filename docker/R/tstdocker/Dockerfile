FROM mattmariano/sec:R_N_PG_UBUNTU_JAMMY
WORKDIR /
#COPY . .
ARG OPTIONALS="true"
ENV R_VERSION=4.5.2
ENV USERNAME=sec
ENV USERID=10000

#
VOLUME [ "/opt/R/sec_poc" ]
COPY docker/R/files/init_ubuntu_repos.sh .

COPY docker/R/files/ubuntu-sources.list /etc/apt/sources.list.d/ubuntu.sources
#RUN ["./init_ubuntu_repos.sh"]
RUN echo "root:root" | chpasswd


RUN ["cat", "/etc/apt/sources.list.d/ubuntu.sources"]
RUN ["cat", "/etc/apt/sources.list.d/ubuntu.sources"]
RUN ["ls", "-l",  "/etc/apt/sources.list.d/ubuntu.sources"]



RUN apt update && apt install -y \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
RUN cat /etc/apt/sources.list /etc/apt/sources.list.d/*


RUN curl -L https://rstd.io/r-install > r-install.sh && \
    chmod u+x r-install.sh && \
    ./r-install.sh -i $R_VERSION -y && \
    ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R && \
    ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript

#ENV PATH="$PATH:/opt/R/${R_VERSION}/lib/R/bin"
#RUN export PATH=PATH="$PATH:/opt/R/${R_VERSION}/lib/R/bin"

#RUN /opt/R/${R_VERSION}/bin/R --version
#
RUN apt install -y software-properties-common
RUN add-apt-repository main
RUN add-apt-repository universe
RUN add-apt-repository restricted
RUN add-apt-repository multiverse
#RUN add-apt-repository ppa:mc3man/trusty-media
RUN apt update
RUN apt dist-upgrade -y
#RUN add-apt-repository ppa:c2d4u.team/c2d4u4.0+
RUN apt update

RUN apt install -y git
RUN apt install -y cmake
RUN apt install -y aptitude
RUN apt install -y -f
#RUN apt install -y --allow-downgrades libfreetype6=2.11.1+dfsg-1ubuntu0.3
#RUN apt install -y libfreetype6=2.11.1+dfsg-1ubuntu0.3
#RUN apt install -y libfreetype-dev=2.11.1+dfsg-1ubuntu0.3
#libfreetype6-dev=2.11.1+dfsg-1ubuntu0.3
RUN apt install -y libicu70
RUN apt install -y --allow-downgrades  \
    libfontconfig1-dev \
    libfreetype-dev \
    libfribidi-dev \
    libgdal-dev \
    libgeos-dev \
    libharfbuzz-dev \
    libssl-dev \
    libpq-dev \
    libproj-dev \
    libsqlite3-dev \
    libjpeg-dev \
    libproj-dev \
    libabsl-dev \
    libudunits2-dev \
    libpng-dev \
    libtiff-dev \
    libxml2-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev  && \
    apt clean all
RUN  apt update
RUN apt install -y wget
RUN apt install --no-install-recommends software-properties-common dirmngr

    # add the signing key (by Michael Rutter) for these repos
# To verify key, run gpg --show-keys /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
# Fingerprint: E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
# add the repo from CRAN -- lsb_release adjusts to 'noble' or 'jammy' or ... as needed
#RUN add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
# install R itself
RUN apt install -y --no-install-recommends r-base
#
RUN (type -p wget >/dev/null || ( apt update &&  apt install wget -y)) \
	&&  mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out |  tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&&  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&&  mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |  tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&&  apt update \
	&&  apt install gh -y
#RUN Rscript -e "options(repos = c(CRAN = sprintf(\"https://packagemanager.posit.co/cran/__linux__/noble/latest-%s/%s\", R.version[\"arch\"], substr(getRversion(), 1, 3))));install.packages(\"renv\")"
#RUN Rscript -e "options(repos = c(CRAN = \"https://packagemanager.posit.co/cran/__linux__/noble/latest\"));install.packages(\"renv\");renv::restore()"
#RUN Rscript -e "options(repos = c(CRAN = sprintf(\"https://packagemanager.posit.co/cran/__linux__/noble/latest-%s/%s\", R.version[\"arch\"], substr(getRversion(), 1, 3))));install.packages(\"renv\");renv::restore()"
COPY docker/R/files .

RUN apt install -y r-base-dev
#RUN Rscript --save -e "options(repos = c(CRAN = \"https://cloud.r-project.org\"));install.packages(\"remotes\")"
#RUN Rscript --save -e "options(repos = c(CRAN = \"https://cloud.r-project.org\"));install.packages(c(\"brio\", \"desc\", \"digest\", \"evaluate\", \"fansi\", \"memoise\", \"rlang\", \"vctrs\", \"withr\", \"yaml\"))"
#RUN Rscript --save -e "options(repos = c(CRAN = \"https://cloud.r-project.org\"));install.packages(c(\"cli\", \"lifecycle\", \"magrittr\", \"rlang\", \"vctrs\"), dependencies = TRUE)"
#RUN Rscript --save -e "options(repos = c(CRAN = \"https://cloud.r-project.org\"));install.packages(c(\"usethis\", \"cli\", \"desc\", \"ellipsis\", \"fs\", \"lifecycle\", \"memoise\", \"miniUI\", \"pkgbuild\", \"pkgdown\", \"pkgload\", \"profvis\", \"rcmdcheck\", \"remotes\", \"rlang\", \"roxygen2\", \"rversions\", \"sessioninfo\", \"testthat\", \"urlchecker\", \"withr\"))"

RUN apt install -y libsqlite3-dev
RUN apt install -y pkg-config
RUN Rscript --save quick-install-r-packages2.R
#RUN sysctl -w "net.ipv4.ping_group_range=0 2000000"
#EXPOSE 8080
CMD ["tail -f /dev/null"]