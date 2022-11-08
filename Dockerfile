# This file is auto generated from it's template,
# see citusdata/tools/packaging_automation/templates/docker/latest/latest.tmpl.dockerfile.
FROM postgres:13.4
ARG VERSION=10.1.2
LABEL maintainer="Scale MobilityDB project https://" \
      org.label-schema.name="MobilityDB in AWS" \
      org.label-schema.description="Sharding PostgreSQL database using Citus extension on top of MobilityDB extension" \
      org.label-schema.version=${VERSION} \
      org.label-schema.schema-version="1.0"

ENV CITUS_VERSION ${VERSION}.citus-1
ENV MOBILITYDB_GIT_HASH bce48f2ec6dffda1d19dd7fd8de191b2a4866d8b
ENV POSTGRES_DBNAME=postgres
ENV POSTGRES_USER=postgres 
ENV POSTGRES_PASSWORD=postgres
ENV POSTGIS_VERSION 2.5

# Fix the Release file expired problem
RUN echo "Acquire::Check-Valid-Until \"false\";\nAcquire::Check-Date \"false\";" | cat > /etc/apt/apt.conf.d/10no--check-valid-until

# Install MobilityDB Prerequisites 
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       build-essential \
       cmake \
       git \
       libproj-dev \    
       g++ \
       wget \
       autoconf \
       autotools-dev \
       libgeos-dev \
       libpq-dev \
       liblwgeom-dev \
       libproj-dev \
       libjson-c-dev \
       protobuf-c-compiler \
       xsltproc \
       libgsl-dev \
       libgslcblas0 \
       postgresql-server-dev-13 \
    && apt-cache showpkg postgresql-13-postgis-$POSTGIS_VERSION \
    && apt-get install -y \
       postgresql-13-postgis-$POSTGIS_VERSION \
       postgresql-13-postgis-$POSTGIS_VERSION-scripts \
    && rm -rf /var/lib/apt/lists/*

# Install citus
RUN curl -s https://install.citusdata.com/community/deb.sh | bash \
    && apt-get install -y postgresql-$PG_MAJOR-citus-10.1.=$CITUS_VERSION \
                          postgresql-$PG_MAJOR-hll=2.15.citus-1 \
                          postgresql-$PG_MAJOR-topn=2.3.1 \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*




# Install MobilityDB 
RUN cd /usr/local/src/ \
  && git clone https://github.com/MobilityDB/MobilityDB.git \
  && mkdir ais_dataset \
  && cd MobilityDB \
  && git checkout ${MOBILITYDB_GIT_HASH} \
  && mkdir build \
  && cd build && \
	cmake .. && \
	make -j$(nproc) && \
	make install

# Add an AIS dataset to test our MobilityDb queries
ADD https://github.com/bouzouidja/MobilityDB-AWS/tree/master/data/mobility_dataset.csv  /usr/local/src/ais_dataset


# add citus to default PostgreSQL config
RUN echo "shared_preload_libraries='citus'" >> /usr/share/postgresql/postgresql.conf.sample


# add scripts to run after initdb
COPY ./initdb-mobilitydb-aws.sh /docker-entrypoint-initdb.d/mobilitydb.sh
RUN chmod +x /docker-entrypoint-initdb.d/mobilitydb.sh



# add health check script
COPY pg_healthcheck wait-for-manager.sh /
RUN chmod +x /wait-for-manager.sh

# entry point unsets PGPASSWORD, but we need it to connect to workers
# https://github.com/docker-library/postgres/blob/33bccfcaddd0679f55ee1028c012d26cd196537d/12/docker-entrypoint.sh#L303
RUN sed "/unset PGPASSWORD/d" -i /usr/local/bin/docker-entrypoint.sh

HEALTHCHECK --interval=4s --start-period=6s CMD ./pg_healthcheck