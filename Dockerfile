FROM quay.io/centos/centos:stream9 as bingo

RUN dnf update -y && dnf upgrade -y 
RUN dnf install -y tar git cmake gcc-c++ 
RUN dnf install -y dnf-plugins-core 
RUN dnf config-manager --set-enabled crb
RUN dnf install -y libstdc++-static 
RUN dnf install -y perl-IPC-Run 

# Install PostgreSQL 15
RUN dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
RUN dnf -qy module disable postgresql
RUN dnf install -y postgresql15-server postgresql15
RUN dnf install -y postgresql15-devel 
RUN dnf clean all && dnf update

# Add PostgreSQL binaries to PATH and set PGDATA
ENV PATH=$PATH:/usr/pgsql-15/bin
ENV PGDATA=/var/lib/pgsql/15/data

# Set directories with correct permissions
RUN chown -R postgres:postgres /var/lib/pgsql && \
    chmod 700 /var/lib/pgsql/15/data

ENV INDIGO_VERSION master

RUN git clone --depth 1 --branch $INDIGO_VERSION https://github.com/epam/indigo && \
    cd indigo && \
    mkdir build && \
    cd build && \
    cmake .. \
    -DPostgreSQL_PG_CONFIG=/usr/pgsql-15/bin/pg_config \
    -DPostgreSQL_INCLUDE_DIR=/usr/pgsql-15/include/server \
    -DPostgreSQL_LIBRARY=/usr/pgsql-15/lib/libpq.so \
    -DBUILD_BINGO_POSTGRES=ON \
    -DBUILD_BINGO_SQLSERVER=OFF \
    -DBUILD_BINGO_ORACLE=OFF \
    -DBUILD_INDIGO=OFF \
    -DBUILD_INDIGO_WRAPPERS=OFF \
    -DBUILD_INDIGO_UTILS=OFF \
    -DBUILD_BINGO_ELASTIC=OFF && \
	cmake --build . --config Release --target package-bingo-postgres -- -j $(nproc)

FROM postgres:15

RUN usermod -u 2005 postgres && \
    groupmod -g 2005 postgres
    
COPY --from=bingo /indigo/build/bingo-postgres15-linux-*/ /bingo-build
WORKDIR /bingo-build
USER root
RUN cp ./lib/libbingo-postgres.so /usr/lib/postgresql/15/lib && \
    /bin/sh ./bingo-pg-install.sh -libdir /usr/lib/postgresql/15/lib/ -y

# USER root
COPY src/* /docker-entrypoint-initdb.d/
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint-initdb.d/*.sh
RUN chmod +x /docker-entrypoint.sh

ENV ACAS_SCHEMA=acas
ENV ACAS_USERNAME=acas
ENV ACAS_PASSWORD=acas
ENV DB_NAME=acas
ENV DB_USER=acas_admin
ENV DB_PASSWORD=acas_admin
ENV POSTGRES_PASSWORD=postgres

CMD ["postgres", "-D", "/var/lib/pgsql/15/data", "-c", "log_connections=on", "-c", "log_disconnections=on"]
