#!/bin/bash

if [ ! -d /home/${USER}/data ] ; then 
    mkdir -p "$HOME/data/mariadb";
    mkdir -p "$HOME/data/wordpress";
fi