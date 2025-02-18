

docker buildx build --push --platform linux/arm64/v8,linux/amd64 --tag mcneilco/acas-postgres:release-2022.4.x .


The docker container was updated centos 9 app image.

Postgres 15 was used.

Container starts with Centos, Indigo creates a cluster and then Postgres is copied to a Debian container.