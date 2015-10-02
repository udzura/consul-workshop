#!/bin/bash

if [ "$1" = "clean" ]; then
  rm -vrf rmps/* checkout/hashibuilder/pkg/*
  exit
fi

mkdir -p ./rpms ./checkout

( cd checkout;
  test -d hashibuilder || git clone https://github.com/udzura/hashibuilder.git;
  cd hashibuilder;
  docker-compose build consul-rpm;
  docker-compose run consul-rpm;
  docker-compose build consul-template-rpm;
  docker-compose run consul-template-rpm )

mv -v ./checkout/hashibuilder/pkg/RPMS/x86_64/*.rpm ./rpms/
