# Appkata-mqtt

Run your own MQTT server for event-based messaging on Fly

<!---- cut here --->

## Rationale

Your modern application is more reactive than ever and with an event-based messaging platform like MQTT, you can communicate  and react more than ever. MQTT allows for publish and subscribe messages to be sent to topics and broadcast to listening clients with options to persist data and enforce quality of service on connections. 

We'll be using Mosquitto, a popular free MQTT broker, to create a persistent messaging hub on Fly.

## Preparing

You will need [Mosquitto](https://github.com/eclipse/mosquitto) installed locally as we'll be using some of its tools in the process of creating and testing our server. The other thing we'll need is [mkcert](https://github.com/FiloSottile/mkcert), which allows you to create your own certificate authority and certificates. If you are in macOS, install [Homebrew](https://brew.sh/) and then run `brew install mosquitto mkcert`. 

## Initialising

We're ready to begin building on the official Mosquitto image, eclipse-mosquitto and making some changes to it with a Dockerfile:

```
FROM eclipse-mosquitto:openssl

RUN mkdir /etc/mosquitto
ADD mosquitto.conf /etc/mosquitto
ADD passwd /etc/mosquitto
ADD certs /etc/mosquitto/certs

CMD ["/usr/sbin/mosquitto", "-c", "/etc/mosquitto/mosquitto.conf"]
```

We select the openssl build of Mosquitto and then add a mosquitto config directory to it in `/etc/mosquitto`. We then copy over a configuration file, passwords and certificates to the image. We wrap up with a startup command which runs Mosquitto using our configuration.

Now we need to create a slot fot the application on Fly. Run

```
fly init appkata-mqtt --dockerfile --port 1883 --org personal
```

And it will create a Fly app called `appkata-mqtt` (though you'll have to find another name because fly app names are unique - if you are having trouble making one miss out the app name and Fly will generate one for you). It will also create a `fly.toml` file which will use the Dockerfile to build the app. We'll come back to that later. For now, the most important thing to know is the app name.

All that's missing are all those files. Let's go fill in the gaps.

## mosquitto.conf

This file sets up the server:

```
persistence true
persistence_file mosquitto.db
persistence_location /mosquitto/data/

allow_anonymous false
password_file /etc/mosquitto/passwd

cafile /etc/mosquitto/certs/rootCA.crt
certfile /etc/mosquitto/certs/mqtt-server.crt
keyfile /etc/mosquitto/certs/mqtt-server.key
require_certificate false
tls_version tlsv1.2
```

A quick run through this file is in order. First, we set up where Mosquitto will persist data; specifically in a file called `/mosquitto/data/mosquitto.db`. 

Then we are on to password configuration: we require them and the password file will be in `/etc/mosquitto/passwd`. Third, we set up the TLS/SSL parameters. Mostly the locations of files we will create soon, and some settings, like `require_certificate` set to false to turn off client authentication and a reasonable selection of TLS version for communications.

## Passwords 

Let's create that password file. This is simply a matter of coming up with a username and password and then running

```
mosquitto_passwd -c ./passwd username
```

It'll prompt you for a password (twice) and generate out password file. If you want more users and passwords, check out the mosquitto_passwd docs where it covers batch modes and converting plaintext passwords into hashed passwords. Now we have that in place, that just leaves the certificates.

## Certificates

This is where we use `mkcert`. In one command, we'll ask it to generate 

```
mkcert -key-file certs/mqtt-server.key -cert-file certs/mqtt-server.crt appkata-mqtt.fly.dev
```



