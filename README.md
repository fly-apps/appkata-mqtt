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

We select the openssl build of Mosquitto and then add a mosquitto config directory to it in `/etc/mosquitto`. We then copy over a configuration file, passwords, and certificates to the image. We wrap up with a startup command which runs Mosquitto using our configuration.

Now we need to create a slot for the application on Fly. Run

```cmd
fly init appkata-mqtt --dockerfile --port 1883 --org personal
```
```out

Selected App Name: appkata-mqtt


New app created
  Name         = appkata-mqtt
  Organization = personal       
  Version      = 0              
  Status       =                
  Hostname     = <empty>        

App will initially deploy to lhr (London, United Kingdom) region

Wrote config file fly.toml
```

And it will create a Fly app called `appkata-mqtt` (though you'll have to find another name because fly app names are unique - if you are having trouble making one miss out the app name and Fly will generate one for you). It will also create a `fly.toml` file which will use the Dockerfile to build the app. There are to the most important things to know are the app name and the region where the app will deploy - in this case, lhr.

All that's missing now are all those files. Let's go fill in the gaps.

## mosquitto.conf

This file sets up the server:

```
persistence true
persistence_file mosquitto.db
persistence_location /mosquitto/data/

allow_anonymous false
password_file /etc/mosquitto/passwd

cafile /etc/mosquitto/certs/rootCA.pem
certfile /etc/mosquitto/certs/mqtt-server.crt
keyfile /etc/mosquitto/certs/mqtt-server.key
require_certificate false
tls_version tlsv1.2
```

A quick run through this file is in order. First, we set up where Mosquitto will persist data; specifically in a file called `/mosquitto/data/mosquitto.db`. 

Then we are on to password configuration: we require them and the password file will be in `/etc/mosquitto/passwd`. Third, we set up the TLS/SSL parameters. Mostly the locations of files we will create soon, and some settings, like `require_certificate` set to false to turn off client authentication and a reasonable selection of TLS version for communications.

## Passwords 

Let's create that password file. This is simply a matter of coming up with a username and password and then running

```cmd
mosquitto_passwd -c ./passwd username
```

It'll prompt you for a password (twice) and generate out password file. If you want more users and passwords, check out the mosquitto_passwd docs where it covers batch modes and converting plaintext passwords into hashed passwords. Now we have that in place, that just leaves the certificates.

## Certificates

This is where we use `mkcert`. In one command, we'll ask it to generate 

```
mkcert -key-file certs/mqtt-server.key -cert-file certs/mqtt-server.crt appkata-mqtt.fly.dev
```

This will create a set of certificates for our server at `appkata-mqtt.fly.dev` - remember to replace the hostname with your app name followed by .fly.dev to make your own certificates.

As mkcert generates its own CA root, to use these certificates, we need a copy of that root.

```cmd
cp "$(mkcert -CAROOT)/rootCA.pem" certs/rootCA.pem
```

This set of three files will allow the server to use TLS. Incoming clients will need the certs/rootCA.pem file to work with this server, so make sure you have a copy.

## Services and Volumes

With the Mosquitto configuration done, we now need to prepare the Fly configuration. The first part of this is creating the volume to store the persistent data. We've already mentioned the directory name in `mosquitto.conf` and the persistence location setting. Now we need to create a Fly disk volume to hold that data in the region where the app will deploy. We got that information when we initialized the app at the start. We'll make a `mosquitto_data` volume.

```cmd
fly volumes create mosquitto_data --region lhr
```

As it stands, that volume is not connected to our application. That can be set up in the `fly.toml` file. Open it and add these lines:

```toml
[[mounts]]
source="mosquitto_data"
destination="/mosquitto/data"
```

This will mount the volume at `/mosquitto/data`. Before you close, there is something else to do in `fly.toml` and thats configure the services. By default, the `fly.toml` file directs traffic on port 80 and port 443 to the internal port like so:

```
  [[services.ports]]
    handlers = ["http"]
    port = "80"

  [[services.ports]]
    handlers = ["tls", "http"]
    port = "443"
```

Well, we aren't going to set a handler for MQTT traffic and we're going to use port 10000 for it. So replace those two sections of config with:

```toml
  [[services.ports]]
    handlers = [ ]
    port = "10000"
```

Save the file and we're ready to deploy.

## Deploying and Testing

To deploy our server is simple:

```cmd
fly deploy
```

Once deployed, we'll want to test it. Open up two terminals. In one terminal we'll set up a subscribe to listen to all topics:

```cmd
mosquitto_sub -L mqtts://username:password@appkata-mqtt.fly.dev:10000/# --cafile certs/rootCA.pem
```

Insert the username and passwords you used when creating the passwd file with mosquitto_passwd. 

Now go to the other terminal and run:

```cmd
mosquitto_pub -L mqtts://username:password@appkata-mqtt.fly.dev:10000/tests --cafile certs/rootCA.pem  -l
```

Now type something and hit return and it should show up in the sub terminal. You now have a working, TLS encrypted, username/password authorized Mosquitto server, ready to rebroadcast your message traffic.

## Discuss

* You can discuss this example on its dedicated [community.fly.io](https://community.fly.io/t/appkata-mqtt/390) topic.



