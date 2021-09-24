FROM store/internetsystemsconsortium/bind9:9.16

RUN apt-get update -qq && apt-get -qqy upgrade && apt-get install -qqy \
    curl nginx git && \
    apt-get clean

RUN apt-get update -qq && apt-get install -qqy --no-install-recommends \
    nano && \
    apt-get clean

COPY files /docker

RUN bash /docker/install.sh

CMD bash /docker/start.sh
