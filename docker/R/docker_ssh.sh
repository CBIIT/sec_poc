# Simple script to allow attaching to a running container with a shell.
# Not really ssh but the same effect.
#!/bin/bash

set -e

dpid="$(docker ps -q)"
exec docker exec -i -t $dpid /bin/bash
