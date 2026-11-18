#!/bin/sh
dub build --compiler=ldc2 --build=release --arch=x86_64 || exit 1
strip serve-destiny
VERSION=$(./serve-destiny --version 2>&1 | grep -oh "serve-destiny standalone v[0-9]*\.[0-9]*\.[0-9]*" | sed "s/serve-destiny standalone v//")
echo $VERSION > version.txt
echo $VERSION
tar cfJ serve-destiny_$VERSION-linux-x86_64.tar.xz serve-destiny
tar czf serve-destiny_$VERSION-linux-x86_64.tar.gz serve-destiny

