if [ "(basename $PWD)" != "yusuken" ]
  cd ~
end

source ~/.config/fish/alias.fish
source ~/.config/fish/path.fish
source ~/.asdf/asdf.fish

eval "$(zoxide init fish)"

# Generated for envman. Do not edit.
test -s ~/.config/envman/load.fish; and source ~/.config/envman/load.fish
