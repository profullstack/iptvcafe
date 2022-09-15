#!/bin/bash

MOJO_LISTEN=http://*:5000 MOJO_REVERSE_PROXY=1 morbo ./script/mojo_forum deamon
