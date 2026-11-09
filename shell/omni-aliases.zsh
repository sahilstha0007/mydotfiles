# OmniRoute service control. Both are *user* units (~/.config/systemd/user),
# so no sudo - `sudo systemctl --user` looks at root's units and fails.
# Kept in $HOME because ml4w owns ~/.config/zshrc and wipes it on update.
# ponytail: one alias per action; add omnidoctor when you actually need it.

alias omnion='systemctl --user start omniroute omniroute-proxy'
alias omnioff='systemctl --user stop omniroute omniroute-proxy'
alias omnienable='systemctl --user enable omniroute omniroute-proxy'
alias omnidisable='systemctl --user disable omniroute omniroute-proxy'
alias omnirestart='systemctl --user restart omniroute omniroute-proxy'
alias omnistatus='systemctl --user --no-pager status omniroute omniroute-proxy'
alias omnilogs='journalctl --user -u omniroute -u omniroute-proxy -f --no-pager'
alias omnilog='journalctl --user -u omniroute -u omniroute-proxy -n 100 --no-pager'
