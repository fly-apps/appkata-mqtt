FROM eclipse-mosquitto:openssl

RUN mkdir /etc/mosquitto
ADD mosquitto.conf /etc/mosquitto
ADD passwd /etc/mosquitto
ADD certs /etc/mosquitto/certs

CMD ["/usr/sbin/mosquitto", "-c", "/etc/mosquitto/mosquitto.conf"]
