FROM store/internetsystemsconsortium/bind9:9.16

RUN apt-get update -qq && apt-get -qqy upgrade && apt-get install -qqy \
    curl nginx

COPY files /docker

RUN bash /docker/install.sh

CMD bash /docker/start.sh
