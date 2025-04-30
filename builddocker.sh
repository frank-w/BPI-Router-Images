#!/bin/bash

docker build -t bpi-router-images .

rm -rf bpi-* *.md5 *.img *.gz

docker run --rm --privileged -v /dev:/dev -v /proc:/proc -v $(pwd):/build bpi-router-images ./buildimg.sh $1 $2 $3
