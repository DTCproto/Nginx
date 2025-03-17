#!/bin/sh

nginx -V
nginx -t
nginx -g "daemon off;"
