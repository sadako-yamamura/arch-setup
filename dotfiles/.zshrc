# --- Completion System ---
autoload -Uz compinit
compinit

# Menu-based completion, case-insensitive matching, and typo tolerance
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' completer _complete _approximate

# --- History Configuration ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# --- Keybindings (Prefix-Aware History Search) ---
bindkey '\e[A' history-beginning-search-backward
bindkey '\e[B' history-beginning-search-forward

# --- Smart Word Navigation ---
autoload -Uz select-word-style
select-word-style normal
zstyle ':zle:*' word-style unspecified

# --- Starship Prompt ---
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  autoload -Uz colors && colors
  PROMPT="%F{green}%n@%m%f:%F{blue}%~%f%# "
fi

# --- Modern CLI Tool Integrations ---
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
