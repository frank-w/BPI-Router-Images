#!/bin/bash

docker build -t bpi-router-images .

rm -rf *.gz debian_*

docker run --rm --privileged -v $(pwd):/build bpi-router-images ./buildimg.sh $1 $2 $3
