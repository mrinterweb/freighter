# Freighter

Freighter's goal is to make it easy to deploy docker containers over ssh. Freighter uses one YAML file to describe the environments, servers, images, and containers in your environment.

Freighter goals:
* Simple docker container deployment
* Straight forward configuration
* Users new to freighter should be able to deploy in minutes
* Minimal server-side configuration
* Clean up old containers and images that are not being used
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

Running the docker REST API this way should be secure since all communication to the API is over an SSH tunnel, and the docker REST API should only be available locally on the host.

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
freighter -e staging --all deploy
```

If you want to deploy one app:
```
freighter -e staging --app my_app deploy
```

The apps are defined in freighter.yml.

## freighter.yml

When you run `freighter configure` it will copy an example freighter.yml file that you can use as a template. The structure of the YAML file is important. More documentation on configuration to come.

Here is what part of the example freighter YAML configuration looks like:
```YAML
connection:
  type: ssh
  ssh_options:
    config: true
    # user_name: user name on host
    # keys:
    #  - "~/.config/id_rsa"

docker:
  port: 2375

environments:
  staging:
    hosts:
      - host: staging.example.com
        images:
          - name: organization/imageName:latest
            containers:
              - name: app
                port_mapping: 0.0.0.0:80->80
                env:
                  DB_USERNAME: fooBar
                  DB_PASSWORD: My53cr37
```
Breaking this example down:

```YAML
connection:
  type: ssh
  ssh_options:
    config: true
    # user_name: user name on host
    # keys:
    #  - "~/.config/id_rsa"
```
This specifies the connection used to connect to the host servers. Currently, SSH via key based authentication is the only method supported. In order to deploy, you'll need to be able to SSH into all host server you are attempting to deploy to. More connection options may be provided in the future.

There are many ssh_options available. See the following documented here: http://net-ssh.github.io/net-ssh/ (for the "start" method's options). One additional options is "user_name" that was added. You can also use the "--user" option when running freighter to override the user_name in the freighter.yml. For the most simple and flexible configuraiton, use the `config: true` option and that will load your ~/.ssh/config, /etc/ssh_config files to determine how to connect to the hosts.

If more than one user uses freighter to deploy, specifying the user_name in the freighter.yml is not recommended. Use the `config: true` option or the `--user` flag option.

```YAML
docker:
  port: 2375
```
This specifies the port the docker REST API is running on the host servers. This port should be consistent across all host servers running docker. This port is specified in /etc/default/docker on the hosts, and more information is supplied in the installation instructions. A SSH tunnel is established tunneling TCP traffic from your local machine starting on port 7000 to the host server's localhost:<configured-port>.

```YAML
environments:
  staging:
    hosts:
      - host: staging.example.com
        images:
          - name: organization/imageName:latest
            containers:
              - name: app
                port_mapping: 0.0.0.0:80->80
                env:
                  DB_USERNAME: fooBar
                  DB_PASSWORD: My53cr37
```

This is where you specify your environments > hosts > images > containers. The formatting was designed to help make it easy to see how the containers are deployed. 

The parser uses Ruby's Psych ruby parser. More details on YAML formatting can be found here: http://www.yaml.org/spec/1.2/spec.html. It is possible to use advanced YAML formatting options to reduce redundancy in your freighter.yml file. The "production" environment in the example freighter.yml shows a basic way that YAML can be formatted to reduce redundancy. I didn't want to get too fancy in this file, but that shouldn't stop you. So long as the following is defined, you should be fine:
* environments
* environments/hosts (must be an array)
* environments/hosts/images (must be an array)
* environments/hosts/images/containers (must be an array)

The above YAML example will evaluate to the equivalent JSON representation.
```javascript
{
  "environments": {
    "staging": {
      "hosts": [{
        "host": "staging.example.com",
        "images": [{
          "name": "organization/imageName:latest",
          "containers": [{
            "name": "app",
            "port_mapping": "0.0.0.0:80->80", 
            "env": {
              "DB_USERNAME": "fooBar",
              "DB_PASSWORD": "My53cr37"
            }
          }]
        }]
      }]
    }
  }
}
```

## Fun facts

If you find yourself in a pickle of not being able to Ctrl+c (interrupt) the command. Ctrl+z (suspend) the process and the kill the pid with `kill -6 <pid>`. I'll try to fix it so that this scenario is more avoidable.

# Status

Freighter is currently deploying quickly and reliably as far as I can tell.

Needed:
* Needs more testing with more complex scenarios
* Container linking options
* Volume mounting options

## Contributing

1. Fork it ( https://github.com/[my-github-username]/freighter/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
