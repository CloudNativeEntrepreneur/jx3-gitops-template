#!/usr/bin/env sh

echo "waiting for completed file: jx-boot-completed.txt"

while [ ! -f  jx-boot-completed.txt ]; do sleep 1; done

echo "completed"

