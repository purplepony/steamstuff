#! /bin/bash

while read uri; do # Iteratively parse group ID from URLs in STDIN
	./fetch.sh `echo $uri | cut -d '/' -f 5` $1
done
