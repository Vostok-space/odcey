#!/bin/sh

set -e

CMD=${1:-"built/odcey"}

$CMD text tests/BB-Chars.odc built/BB-Chars.txt
cmp --silent -- tests/BB-Chars.txt built/BB-Chars.txt || echo failed BB-Chars

$CMD tests/Tut-6.odc -write-descriptors built/Tut-6.txt
cmp --silent -- tests/Tut-6.txt built/Tut-6.txt || echo failed Tut-6
