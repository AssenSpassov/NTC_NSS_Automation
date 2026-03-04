# ================================================================== 
# Assen's bashrc

# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
source ~/.aliases

# https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh
GIT_PS1_SHOWDIRTYSTATE=y
source ~/.git-prompt.sh

#MY_TOKEN="437684feed82f6ba35852391f2590a5ba82da710"

# prompt for the production VM!
#PS1="[\033[36m\u\033[m@\033[31m\h\033[m \033[33m\W\033[m]\$ "

#prompt for root:
export PS1="[\[$(tput sgr0)\]\[\033[38;5;9m\]\u\[$(tput sgr0)\]@\[$(tput sgr0)\]\[\033[38;5;14m\]\h\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;11m\]\W\[$(tput sgr0)\]]\\$ \[$(tput sgr0)\]"

# prompt for the mgmt VM itself
# Build the space-separated list (your current pipeline)
available_clusters_str="$(cat ~/.ssh/config \
  | grep cvm1 \
  | awk '{print $NF}' \
  | awk -F- '{printf "%s ", $1}' ; echo)"

# Convert to an array (split on IFS=space)
read -r -a available_clusters <<< "$available_clusters_str"

# If nothing found, bail out gracefully
if (( ${#available_clusters[@]} == 0 )); then
  echo "No clusters found in ~/.ssh/config (grep cvm1 returned nothing)."
  # Optionally: unset cluster4prompt; return/exit
  unset cluster4prompt
else
  # Print a numbered list
  echo "Available clusters:"
  for i in "${!available_clusters[@]}"; do
    printf "  %2d) %s\n" "$((i+1))" "${available_clusters[$i]}"
  done

  # Prompt showing both the names and the allowed numeric range
  printf "Which cluster is this shell for (%s) [1-%d]: " \
    "$available_clusters_str" "${#available_clusters[@]}"

  read -r cluster4prompt

  # Trim whitespace
  cluster4prompt="${cluster4prompt##+([[:space:]])}"
  cluster4prompt="${cluster4prompt%%+([[:space:]])}"

  # If input is a number in range, map to the corresponding element
  if [[ "$cluster4prompt" =~ ^[0-9]+$ ]]; then
    if (( cluster4prompt >= 1 && cluster4prompt <= ${#available_clusters[@]} )); then
      cluster4prompt="${available_clusters[$((cluster4prompt-1))]}"
    else
      echo "Invalid number: must be between 1 and ${#available_clusters[@]}."
      unset cluster4prompt
    fi
  else
    # If input is not a number, accept exact match of a cluster name
    found=""
    for c in "${available_clusters[@]}"; do
      if [[ "$cluster4prompt" == "$c" ]]; then
        found="yes"
        break
      fi
    done
    if [[ -z "$found" ]]; then
      echo "Invalid selection: '$cluster4prompt' is not in the list."
      unset cluster4prompt
    fi
  fi
fi

SRG0=$(tput sgr0)
if [ ! -z "$cluster4prompt" ]
 then
  if [ "$cluster4prompt" == "git" ]
   then
    #export PS1='[\033[32m\u\033[m@\033[36m\h\033[m \033[31m($cluster4prompt) \033[33m\W\033[m]$(__git_ps1 " (%s)")\$ '
        # the below variation of the prompt is needed due to readline otherwise not threating non-printable characters properly which leads to issues with longer commands.
        # all non-printable characters need to be escaped with \[ and \] before and after them.
        # more info: https://stackoverflow.com/questions/19092488/custom-bash-prompt-is-overwriting-itself
        # used https://bashrcgenerator.com/ to gengerate the skeleton of the PS1 prompt and then added the $cluster4prompt variable; now home and end buttons work fine in all cases.
        # prompt as per the above site: [<username>@<hostname(short)><space>()<space><directory(basename)>]<#/$><space>
        # and added colors
    export PS1='[\[$(tput sgr0)\]\[\033[38;5;10m\]\u\[$(tput sgr0)\]@\[$(tput sgr0)\]\[\033[38;5;14m\]\h\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;1m\]($cluster4prompt)\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;11m\]\W\[$(tput sgr0)\]]$(__git_ps1 " (%s)")\\$ \[$(tput sgr0)\]'
    window_index=`tmux display-message -p '#I'`
    #tmux rename-window -t $window_index "${cluster4prompt}"
    window_name=`tmux display-message -p '#W'`
    window_name_lower=$(echo "$window_name" | tr '[:upper:]' '[:lower:]')
     if [[ "$window_name_lower" == *"$cluster4prompt"* ]]
      then
       tmux rename-window -t $window_index "${window_name}"
      else
       tmux rename-window -t $window_index "${cluster4prompt}"
     fi
    #cluster4prompt=""
   else
    export PS1='[\[$(tput sgr0)\]\[\033[38;5;10m\]\u\[$(tput sgr0)\]@\[$(tput sgr0)\]\[\033[38;5;14m\]\h\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;1m\]($cluster4prompt)\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;11m\]\W\[$(tput sgr0)\]]$(__git_ps1 " (%s)")\\$ \[$(tput sgr0)\]'
    window_index=`tmux display-message -p '#I'`
    window_name=`tmux display-message -p '#W'`
    window_name_lower=$(echo "$window_name" | tr '[:upper:]' '[:lower:]')
     if [[ "$window_name_lower" == *"$cluster4prompt"* ]]
      then
       tmux rename-window -t $window_index "${window_name}"
      else
       tmux rename-window -t $window_index "${cluster4prompt}"
     fi
    #tmux rename-window -t $window_index "${cluster4prompt}"
  fi
 else
  export PS1='[\[$(tput sgr0)\]\[\033[38;5;10m\]\u\[$(tput sgr0)\]@\[$(tput sgr0)\]\[\033[38;5;14m\]\h\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;1m\]\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;11m\]\W\[$(tput sgr0)\]]$(__git_ps1 " (%s)")\\$ \[$(tput sgr0)\]'
  #window_index=`tmux display-message -p '#I'`
  #tmux rename-window -t $window_index $cluster4prompt

fi
