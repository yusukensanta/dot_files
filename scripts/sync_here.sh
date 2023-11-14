#!/bin/bash

TARGET_DIR=(nvim fish)

for d in ${TARGET_DIR[@]};
do
  cp -r $HOME/.config/$d $PWD/.config/
done

cp /mnt/c/Users/yusuk/AppData/Roaming/alacritty/alacritty.yml $PWD/alacritty/alacritty.yml
cp $HOME/.tmux.conf $PWD/.tmux.conf
