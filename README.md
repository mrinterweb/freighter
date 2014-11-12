# Freighter

Freighter's goal is to make it easy to deploy docker containers over ssh. Freighter uses one YAML file to describe the environments, servers, images, and containers in your environment.

Freighter goals:
* Simple docker container deployment
* Straight forward configuration
* Users new to freighter should be able to deploy in minutes
* Minimal server-side configuration
* Fast and reliable

## Installation
Freighter is a ruby gem and requires ruby 1.9 or higher.

    gem install freighter

## Configuration

After freighter is installed, run the configuration installer.
```
freighter configure
```
This copies an example template of a YAML configuration file into ./config/freighter.yml

### Docker REST API

The way that freighter does not require that users have sudo access on the hosts it deploys to is that it interacts with the docker rest api running on the hosts. This means that docker must be configured to expose its REST API on each host.

```
echo 'DOCKER_OPTS="-H tcp://127.0.0.1:2375 -H unix:///var/run/docker.sock"' | sudo cat >> /etc/default/docker
```

The docker service, on the host(s), will need to be restarted.

Running the docker REST API this way should be secure since all communication to the API is over an SSH tunnel, and the REST API is only available locally on the host.

### Authentication

Currently, this gem supports pulling images from hub.docker.com. This means that you must authenticate. 
It is not recommended to store your personal authentication credentials in freighter.yml since that file 
should be added to source control. Freighter needs the following environment variables set on your local machine:

* DOCKER_HUB_USER_NAME
* DOCKER_HUB_PASSWORD
* DOCKER_HUB_EMAIL

A recommendation would be to create a file only accessible to your machine's user account that defines these environment variables.

```shell
export DOCKER_HUB_USER_NAME=<yourDockerHubUserName>
export DOCKER_HUB_PASSWORD=<yourDockerHubPassword>
export DOCKER_HUB_EMAIL=<yourDockerHubEmail>
```

## Usage

For quick reference:
```
freighter --help
```

Example of how to deploy:
```
freighter -e staging --all deloy
```

If you want to deploy one app:
```
freighter -e staging --app my_app deploy
```

The apps are defined in freighter.yml.

## freighter.yml

When you run `freighter configure` it will copy an example freighter.yml file that you can use as a template. The structure of the YAML file is important. More documentation on configuration to come.

## Fun facts

If you find yourself in a pickle of not being able to Ctrl+c (interupt) the command. Ctrl+z (suspend) the process and the kill the pid with `kill -6 <pid>`. I'll try to fix it so that this scenario is more avoidable.

# Status

Needed:
* Needs more testing with more complex scenarios

Nice to haves:
* Container linking options
* Volume mounting options
* Container cleanup

Freighter is currently deploying quickly and reliably as far as I can tell.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/freighter/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
