#!/bin/sh

CMD=${1:-"built/odcey"}

$CMD text tests/BB-Chars.odc built/BB-Chars.txt
cmp --silent -- tests/BB-Chars.txt built/BB-Chars.txt || echo $CMD failed
