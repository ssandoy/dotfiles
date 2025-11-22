# Tooling and prompts that can load after eager setup.

# SSH Activation
eval $(ssh-agent)
ssh-add $HOME/.ssh/id_rsa
find ~/.ssh/ -type f -exec grep -l "PRIVATE" {} \; | xargs ssh-add &> /dev/null

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

eval "$(oh-my-posh --init --shell zsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin_macchiato.omp.json')"
eval "$(zoxide init zsh)"
