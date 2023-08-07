#!/bin/bash
mapfile -t rc < 3.17.rc
for x in ${rc[@]}; do
	stage=$(echo $x | cut -d , -f 1)
	init=$(echo $x | cut -d , -f 2)
	printf 'stage %s init %s\n' "$stage" "$init"
done
