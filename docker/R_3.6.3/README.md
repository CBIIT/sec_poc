# Docker container to run R v3.6.3

Our current production environment runs R version 3.6.3.  The R maintainers make binary packages of the *current* version of R available, but that's 4.x right now.  It can be non-trivial to install an older version of R, so using this container-based approach may be easier for some.

There are "official" R docker containers available, but I do not recommend them, as they are built on top of a fairly broken install of Debian (it's not even possible to install additional packages).

To run, first install [Docker](https://docs.docker.com/get-docker/), then use the build_and_run.sh script.
