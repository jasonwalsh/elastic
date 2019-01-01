## Contents

- [Purpose](#purpose)
- [Requirements](#requirements)
  - [Local](#local)
  - [Production](#production)
- [Usage](#usage)
  - [Vagrant](#vagrant)
  - [Terraform](#terraform)

## Purpose

This repository contains resources for deploying the [Elastic Stack](https://www.elastic.co/) either locally using [Vagrant](https://www.vagrantup.com/) or in a public cloud (AWS) using [Terraform](https://www.terraform.io/).

## Requirements

### Local

- [Vagrant](https://www.vagrantup.com/downloads.html)

### Production

- [Packer](https://packer.io/downloads.html)
- [Terraform](https://www.terraform.io/downloads.html)

## Usage

### Vagrant

    $ vagrant up

Visit http://localhost:5601

### Terraform

    $ terraform init
    $ terraform plan
    $ terraform apply
