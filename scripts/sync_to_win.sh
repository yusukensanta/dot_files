#!/bin/bash

TARGET_DIR=(nvim fish)

for d in ${TARGET_DIR[@]};
do
  cp -r $PWD/.config/$d $HOME/.config/
done
