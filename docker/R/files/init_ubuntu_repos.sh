#!/bin/bash
echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs) main restricted universe multiverse" > /etc/apt/sources.list.d/ubuntu.sources
echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs)-updates main restricted universe multiverse" >> /etc/apt/sources.list.d/ubuntu.sources
echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs)-security main restricted universe multiverse" >> /etc/apt/sources.list.d/ubuntu.sources
echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs)-backports main universe restricted multiverse" >> /etc/apt/sources.list.d/ubuntu.sources
