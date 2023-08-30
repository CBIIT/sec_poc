# Ubuntu 20 ships with R 3.6.3, the version we want.
FROM ubuntu:20.04

RUN yes |unminimize
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update

# For some reason the order of these installations matters; if you try to do them all
# in one command it errors out.
RUN apt-get install -y build-essential iputils-ping less man r-base vim
RUN apt-get install -y libfontconfig1-dev libfribidi-dev libgit2-dev libharfbuzz-dev libssl-dev libtiff5-dev libxml2-dev
RUN apt-get install -y libcurl4-gnutls-dev
RUN apt-get install -y libcurl4-openssl-dev

RUN mkdir -p /opt/R/CTRP/sec_poc
COPY files/.bashrc /root/.bashrc
COPY files/bootstrap.R /opt/R
RUN Rscript /opt/R/bootstrap.R

ENTRYPOINT ["tail", "-f", "/dev/null"]
