[![Join the chat at https://gitter.im/sonata-nfv/Lobby](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sonata-nfv/Lobby) [![Join the chat at https://gitter.im/sonata-nfv/Lobby](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sonata-nfv/Lobby)

<p align="center"><img src="https://github.com/sonata-nfv/tng-api-gtw/wiki/images/sonata-5gtango-logo-500px.png" /></p>

# 5GTANGO Repositories
This repository contains the development for the [5GTANGO](http://www.5gtango.eu) 's Service Platform Repositories. It holds the API implementation for the Service Platform Repositories component.

## Development
To contribute to the development of the 5GTANGO Catalogue and/or Repositories, you may use the very same development workflow as for any other 5GTANGO Github project. That is, you have to fork the repository and create pull requests.

### Dependencies
It is recommended to use Ubuntu 16.04.4 LTS (Trusty Tahr).

This code has been run on Ruby 2.1.

A connection to a MongoDB is required, this code has been run using MongoDB version 3.2.1.

Root folder provides a script "installation_mongodb.sh" to install and set up a local MongoDB, or you can use mongoexpress to manage the remote mongo databases.

Ruby gems used (for more details see Gemfile):

* [Sinatra](http://www.sinatrarb.com/) - Ruby framework
* [puma](http://puma.io/) - Web server
* [json](https://github.com/flori/json) - JSON specification
* [sinatra-contrib](https://github.com/sinatra/sinatra-contrib) - Sinatra extensions
* [rake](http://rake.rubyforge.org/) - Ruby build program with capabilities similar to make
* [JSON-schema](https://github.com/ruby-json-schema/json-schema) - JSON schema validator
* [jwt](https://github.com/jwt/ruby-jwt) - Json Web Token lib
* [curb](https://github.com/taf2/curb) - HTTP and REST client
* [Yard](https://github.com/lsegal/yard) - Documentation generator tool
* [mongoid-grid_fs](https://github.com/mongoid/mongoid-grid_fs) - Implementation of the MongoDB GridFS specification

### Contributing

You may contribute to the editor similar to other 5GTANGO (sub-) projects, i.e. by creating pull requests.

## Installation

After cloning the source code from the repository, you can run Catalogue-Repositories with the next command:

```sh
bundle install
```

Which will install all the gems needed to run, or if you have docker and docker-compose installed, you can run

```sh
docker-compose up
```

## Usage

The following shows how to start the API server for the Catalogues-Repositories:

```sh
rake start
```

or you can use docker-compose

```sh
docker-compose up
```

The Repositories' API allows the use of CRUD operations to send or retrieve records.
The available records include services records (NSR) and functions records (VNFR).
For testing the Repositories, you can use 'curl' tool to send a request to the API. It is required to set the HTTP header 'Content-type' field to 'application/json' or 'application/x-yaml' according to your desired format.
Remember to set the IP address and port accordingly.

Method GET:

To receive all instances you can use

```sh
 curl http://localhost:4012/records/nsr
```

```sh
 curl http://localhost:4012/records/vnfr
```

To receive an instance by its ID:

```sh
curl -X GET http://localhost:4012/records/nsr/9f18bc1b-b18d-483b-88da-a600e9255868
```

```sh
curl -X GET http://localhost:4012/records/vnfr/9f18bc1b-b18d-483b-88da-a600e9255016
```

Method POST:

To send a record instance

```sh
curl -X POST --data-binary @test_nsr.yaml -H "Content-type:application/x-yaml" http://localhost:4012/records/nsr
```

```sh
curl -X POST --data-binary @test_vnfr.yaml -H "Content-type:application/x-yaml" http://localhost:4012/records/vnfr
```

### API Documentation

API documentation in Swagger can be accessed from https://raw.githubusercontent.com/sonata-nfv/tng-rep/master/doc/tng-rep.yaml

Also you can see all the 5GTANGO API's documentation here: https://sonata-nfv.github.io/tng-doc/

## License

The 5GTANGO Repositories is published under Apache 2.0 license. Please see the LICENSE file for more details.

## Useful Links

To support working and testing with the son-catalogue database it is optional to use next tools:

* [Robomongo](https://robomongo.org/download) - Robomongo 0.9.0-RC4

* [POSTMAN](https://www.getpostman.com/) - Chrome Plugin for HTTP communication

---
#### Lead Developers

The following lead developers are responsible for this repository and have admin rights. They can, for example, merge pull requests.

* Felipe Vicens (felipevicens)
* José Bonnet (jbonnet)

#### Feedback-Channel

* Please use the GitHub issues to report bugs.
* You may use the mailing list [sonata-dev@lists.atosresearch.eu](mailto:sonata-dev@lists.atosresearch.eu)
