#!/bin/bash
service nginx start
/usr/sbin/named -g -c /etc/bind/named.conf -u bind
