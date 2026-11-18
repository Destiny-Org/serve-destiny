set -e
set -x

# one file per compiler run: keeps peak memory low (fits in 4 GB)
# Destiny compiler and Destiny's dub; see docs/destiny.md
DFLAGS="-revert=safedefault -O -release -lowmem" des build --compiler=destiny --arch=$ARCH --build-mode=singleFile
strip serve-destiny
if [ "$CROSS" = 1 ]; then
	ls serve-destiny
else
	./serve-destiny --version
fi

tar cfJ serve-destiny.tar.xz serve-destiny
tar czf serve-destiny.tar.gz serve-destiny
