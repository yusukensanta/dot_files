if [ "(basename $PWD)" != "yusuken" ]
  cd ~
end

set system (cat /proc/version | grep "WSL")
if [ -n "$system" ];
  sudo rm -f /etc/resolv.conf
  echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf > /dev/null
end

source ~/.config/fish/alias.fish
source ~/.config/fish/path.fish

eval "$(zoxide init fish)"
/home/yusuken/.local/bin/mise activate fish | source
