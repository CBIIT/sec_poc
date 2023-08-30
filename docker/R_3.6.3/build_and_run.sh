#!/bin/bash

set -e

docker build -t sec_poc/r .

# Uncomment the following line and modify the first part of the -v argument to
# point to where your sec_poc repo is checked out.  Then that directory will
# be available in the container based on the second part of the argument.
#docker run sec_poc/r -v ~/Dev/CTRP/sec_poc:/opt/R/CTRP/sec_poc
