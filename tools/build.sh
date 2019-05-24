#/bin/bash
set -xe
source /root/.profile
docker load --input $(nix-build --cores 4 ../default.nix --show-trace --keep-failed | grep tar)
#docker push  docker-registry.intr/webservices/php4:master
