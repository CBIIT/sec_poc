# Ubuntu 20 ships with R 3.6.3, the version we want.
FROM ubuntu:20.04

RUN yes |unminimize
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update

# For some reason the order of these installations matters; if you try to do them all
# in one command it errors out.
RUN apt-get install -y build-essential curl iputils-ping less man net-tools r-base vim
RUN apt-get install -y gdal-bin libfontconfig1-dev libfribidi-dev libgdal-dev libgit2-dev libharfbuzz-dev libssl-dev libtiff5-dev libxml2-dev
RUN apt-get install -y libcurl4-gnutls-dev
RUN apt-get install -y libcurl4-openssl-dev

RUN mkdir -p /opt/R
COPY files/install_deps.R /opt/R
RUN Rscript /opt/R/install_deps.R 2>&1 |tee /opt/R/install_deps.log
COPY files/.bashrc /root/.bashrc

ENTRYPOINT ["tail", "-f", "/dev/null"]
