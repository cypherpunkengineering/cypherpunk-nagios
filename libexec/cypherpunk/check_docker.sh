#!/bin/bash
/usr/bin/docker rm -f ${1} > /dev/null 2>&1
/usr/bin/docker ${@:2}
exit $?
