FROM quay.io/centos/centos:stream8 as bingo

RUN \
  dnf update -y && \
  dnf upgrade -y && \
  dnf install -y tar git cmake gcc-c++ && \
  dnf module enable -y postgresql:13 && \
  dnf install postgresql-server-devel postgresql-devel -y && \
  dnf config-manager --set-enabled powertools && \
  dnf install -y libstdc++-static && \
  dnf clean all

ENV INDIGO_VERSION master

RUN git clone --depth 1 --branch $INDIGO_VERSION https://github.com/epam/indigo && \
    cd indigo && \
    mkdir build && \
    cd build && \
	cmake .. -DBUILD_BINGO_POSTGRES=ON -DBUILD_BINGO_SQLSERVER=OFF -DBUILD_BINGO_ORACLE=OFF -DBUILD_INDIGO=OFF -DBUILD_INDIGO_WRAPPERS=OFF -DBUILD_INDIGO_UTILS=OFF -DBUILD_BINGO_ELASTIC=OFF && \
	cmake --build . --config Release --target package-bingo-postgres -- -j $(nproc)

FROM postgres:13

COPY --from=bingo /indigo/build/bingo-postgres13-linux-*/ /bingo-build
WORKDIR /bingo-build
USER root
RUN cp ./lib/libbingo-postgres.so /usr/lib/postgresql/13/lib && \
    /bin/sh ./bingo-pg-install.sh -libdir /usr/lib/postgresql/13/lib/ -y

COPY src/* /docker-entrypoint-initdb.d/

CMD ["postgres", "-c", "log_connections=on", "-c", "log_disconnections=on"]
