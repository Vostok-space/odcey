#!/bin/sh

mkdir -p built

ost to-bin odcey.Cli built/todcey -m .
tests/run.sh built/todcey

ost to-jar odcey.Cli built/todcey.jar -m .
tests/run.sh "java -jar built/todcey.jar"

ost to-js odcey.Cli built/todcey.js -m .
tests/run.sh "node built/todcey.js"
