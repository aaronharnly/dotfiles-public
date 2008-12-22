#
# A collection of useful bash functions
#

#
#
# =========================== useful functions ==============================
#
#

#
# --------------------- Scripting --------------------------
#
# Usage: source_if <path>
#   If a file is present at <path>, it will be sourced into the current script.
source_if()
{
  local path="$1"
  if [ -f "$path" ]; then
    source "$path"
  fi
}

# Usage: doalias <alias> [args]
# executes an alias
doalias()
{
  local cmd="$1"
  shift
  local expanded=$(alias "$cmd" | perl -ne 'if ( m/.*?=.(.*)./ ) { print $1 }')
  echo "Expanded alias: $expanded $@"
  eval $expanded $@
}

#
# --------------------- env-var manipulations --------------------------
#


# Usage: path_append [variable] <path>
#   Appends <path> to the variable [variable],
#     (if [variable] is not supplied, defaults to PATH)
path_append()
{
   local target="$1"
  if [ -z $2 ]; then
    local pathvar=PATH
  else
    local pathvar=$2
  fi

  if [ -e "$target" ]; then
     if [[ ! $(eval echo \${$pathvar}) == *$target* ]]; then
       eval export ${pathvar}=\${$pathvar}:$target
    fi
  fi
}

# Usage: path_prepend [variable] <path>
#   Prepends <path> to the variable [variable],
#     (if [variable] is not supplied, defaults to PATH)
path_prepend()
{
   local target="$1"
  if [ -z $2 ]; then
    local pathvar=PATH
  else
    local pathvar=$2
  fi

  if [ -e "$target" ]; then
     if [[ ! $(eval echo \${$pathvar}) == *$target* ]]; then
       eval export ${pathvar}=$target:\${$pathvar}
    fi
  fi
}


# Usage: path_set <path> <variable>
#   Sets the env variable <variable> to <path>,
#   if and only if <path> exists.
#
path_set()
{
  thepath="$1"
  varname="$2"
  
#  echo "Evaluating: $thepath for $varname"
  
  if [ -e "$thepath" ]; then
#    echo "Path found. Setting $varname to $thepath"
    eval export ${varname}=${thepath}
  fi
#  eval echo "$varname is \${$varname}"
}

path_set_if_empty()
{
   thepath="$1"
   varname="$2"
   varvalue=$(eval echo "\$$varname")
   
   if [ -z "$varvalue" ]; then
      path_set "$thepath" "$varname"
   fi
}

path_print()
{
  varname="$1"
  echo "${varname}="
  eval echo -e \$\{$varname//:/\\\\n\}
}


#
# Sets an env var, by choosing from a key-value list.
# The key-value list is established simply by defining a series of env vars with a common prefix;
#   e.g.
#  WGEN_DB_key1="value1"
#  WGEN_DB_key2="value2"
#  ...
#
#
# Usage: choose <var-to-set> <key-prefix> <key> [-q]
#
#  e.g. choose DB_OF_MY_DREAMS WGEN_DB_ key2
#       will perform:
#       export DB_OF_MY_DREAMS="value2"
#
choose()
{
  local var_to_set="$1"
  local key_prefix="$2"
  local key="$3"
  local quiet_arg="$4"
  if [ ! -z "$quiet_arg" ]; then
    if [ "$quiet_arg" = "-q" -o "$quiet_arg" = "--quiet" ]; then
      local quiet="YES"
    else
      local quiet="NO"
    fi
  else
    local quiet="NO"
  fi
  if [ -z "$key" ]; then # list the possibilities for this variable
    echo "Currently,"
    echo "  ${var_to_set}=$(eval echo \$${var_to_set})"
    echo " "
    echo "Available values:"
    env | perl -ne 'if (m/^'$key_prefix'(\w+)=(.+)/) { printf "%20s: %s\n", $1, $2 }'
  else
    # get the value for the key given
    local value=$(eval echo \$${key_prefix}${key})
    if [ -z "$value" ]; then
      # We don't seem to have a value for that key
      # So we'll just use the key itself as the value
      local value="$key"
    fi
    # set the target variable
    eval export ${var_to_set}="$value"
    if [ "$quiet" != "YES" ]; then
      echo "export ${var_to_set}=$(eval echo \$${var_to_set})"
    fi
  fi
}

#
# --------------------- filepath manipulations --------------------------
#

function basename()
{
  local name="${1##*/}"
  echo "${name%$2}"
}

#
# Usage: left_half <separator> <string>
#
#  returns the left half of <string>, up to & not including <separator>,
#    e.g. left_half . filename.txt   returns filename
function left_half()
{
  local separator="$1"
  local name=${2##*/}
  local name0="${name%${separator}*}"
  echo "${name0:-$name}"
}

#
# Usage: right_half_with_sep <separator> <string>
#
#  returns the right half of <string>, from <separator> forward,
#    including <separator>
#  e.g. right_half_with_sep . filename.txt returns .txt
#
function right_half_with_sep()
{
  local separator="$1"
  local name=${2##*/}
  local name0="${name%${separator}*}"
  local ext=${name0:+${name#$name0}}
  echo "${ext:-${separator}}"
}

#
# Usage: right_half <separator> <string>
#
#   returns the right half of <string>, from <separator> forward
#      (not including <separator>)
#   e.g. right_half . filename.txt   returns txt
function right_half() 
{
  local separator="$1"
  local name=${2##*/}
  local name0="${name%${separator}*}"
  local ext=${name0:+${name#$name0}}
  local ext=${ext#${separator}}
  echo "${ext}"
}

function namename() # get the name without the file extension
{
  echo $(left_half . "$1")
}

function ext() # get the file extension, including '.'
{
  echo $(right_half_with_sep . "$1")
}

function extonly() # get the file extension, without '.'
{
  echo $(right_half . "$1")
}

function dirname()
{
  local dir="${1%${1##*/}}"
  [ "${dir:=./}" != "/" ] && dir="${dir%?}"
  echo "$dir"
}


#
# --------------------- directory navigation --------------------------
#

#
# lf makes a nicely indented listing of directory structure, up
#  to the given depth
#
function lf()
{
  local depth=2
  if [ ! -z $1 ]; then
    depth=$1
  fi
  find . -maxdepth $depth -type d | perl -ne ' $count = @matches = m/\//g; print "  " x $count; print'
}

#
# Usage: mycd <path>
#
#  Replacement for builtin 'cd', which keeps a separate bash-history
#   for every directory.
function mycd()
{
  history -w # write current history file
  builtin cd "$@"  # do actual cd
  local HISTDIR="$HOME/.dir_bash_history$PWD" # use nested folders for history
  if [ ! -d "$HISTDIR" ]; then # create folder if needed
    mkdir -p "$HISTDIR"
  fi
  export HISTFILE="$HISTDIR/${USER}_bash_history.txt" # set new history file
  history -c  # clear memory
  history -r #read from current histfile

  if [ ! -z "$LAUNCHING_APP" ]; then
    if [ "$LAUNCHING_APP" = "Path Finder" ]; then
      pft
      export DONT_RUN_PFF="true"
    fi
  fi
}

#
# back: toggle between current and previous directory.
#  It might be nice to implement this as an actual stack.
#
function back()
{
  if [ ! -z "$OLDPWD" ]; then
    mycd "$OLDPWD"
  fi
}

#
# pff: change terminal directory to current Path Finder folder (pff!)
#
function pff()
{
  # if under Path Finder, cd to the current PF directory
  
  if [ "$OS" = "Darwin" ]; then
    if [ "$LAUNCHING_APP" = "Path Finder" ]; then
      # get new path 
      pf_path=$(osascript "$HOME/software/$PLATFORM/share/scripts/get_path_finder_path.scpt")
      if [ ! -z "$pf_path" ]; then
        if [ "$pf_path" != "$PWD" ]; then
          cd "$pf_path"
        fi
      fi
    fi
  fi
}

#
# pf: open specified directory in Path Finder
#
function pf()
{
   open -a 'Path Finder' $@
}



#
# pft: change Path Finder window to current Path Finder Terminal
#
function pft()
{
  if [ "$OS" = "Darwin" ]; then
    if [ "$LAUNCHING_APP" = "Path Finder" ]; then
      # get new path as a "folder 'blah' of disk 'foo'" type string
      folder_path=`perl -e '$_ = $ENV{PWD}; 
      chomp; @parts = reverse( split(/\//) ); 
      print "folder \""; $folder_str = join("\" of folder \"", @parts); 
      $folder_str =~ s/folder \"$/disk \"\/\"/; 
      print $folder_str'`
      osascript <<EOS
  tell app "Path Finder"
  set the window_list to the Finder windows
  set front_window to item 1 of window_list
  set new_path to $folder_path
  set the target of front_window to new_path
  end tell  
EOS
    fi
  fi
}

function calc()
{
  echo $* | bc
}

#
# ------------------------ Display ---------------------------------
#

# Returns the length, in characters, of the longest of the arguments
function length_of_longest_arg()
{
  local max_length=0
  for arg in "$@"; do
    arg_len=${#arg}
    if [ $arg_len -gt $max_length ]; then
      max_length=$arg_len 
    fi
  done
  echo $max_length
}

#
# Repeats a string the given number of times.
#
# Usage: str_repeat "a" "14"
#
# produces: aaaaaaaaaaaaaa
#
function str_repeat()
{
  local str="$1"
  local n="$2"
  local spaces=$(printf "%*s" $n "")
  if [ "$str" = " " ]; then # hack to print spaces. Must be a better way.
    echo "$spaces"
  else
    echo ${spaces// /${str}}
  fi
}

#
# Usage: display_boxed [--centered] "line one" "line two" "etc."
#
#  Displays the given lines of text in pretty fashion, 
#  wrapped in a plus-and-pipe box. If --centered is
#  passed as the first argument, the lines will be centered
#  (otherwise, left-justified). Example:
#
#  display_boxed --centered "the quick brown fox" "jumped over" "the very lazy dog"
#
#  in unicode:
# ┌─────────────────────┐
# │ the quick brown fox │
# │     jumped over     │
# │  the very lazy dog  │
# └─────────────────────┘
# 
#  and in ascii:
# +---------------------+
# | the quick brown fox |
# |     jumped over     |
# |  the very lazy dog  |
# +---------------------+
#
#
#
function display_boxed()
{
  local top_ascii="+-+"
  local mid_ascii="| |"
  local bot_ascii="+-+"

  local top_unicode="┌─┐"
  local mid_unicode="│ │"
  local bot_unicode="└─┘"

  # choose character set
  if [ "$OS" = "Darwin" ]; then
    local charset="unicode"
  else
    local charset="ascii"
  fi

  local charset_top=$(eval echo \$top_${charset})
  local charset_mid=$(eval echo \$mid_${charset})
  local charset_bot=$(eval echo \$bot_${charset})

  local tl=${charset_top:0:1}
  local tc=${charset_top:1:1}
  local tr=${charset_top:2:1}
  local ml=${charset_mid:0:1}
  local mc=${charset_mid:1:1}
  local mr=${charset_mid:2:1}
  local bl=${charset_bot:0:1}
  local bc=${charset_bot:1:1}
  local br=${charset_bot:2:1}  

  local centered=0
  if [ "$1" = "--centered" ]; then
    centered=1
    shift
  fi

  maxlen=$(length_of_longest_arg "$@")
  let innerwidth=maxlen+2
  
  box_top_center=$(str_repeat "$tc" $innerwidth)
  box_top="${tl}${box_top_center}${tr}"

  box_mid_center=$(str_repeat "$mc" $innerwidth)

  box_bot_center=$(str_repeat "$bc" $innerwidth)
  box_bot="${bl}${box_bot_center}${br}"

  echo "$box_top"
  for line in "$@"; do
    left_spaces_len=0
    if [ $centered -eq 1 ]; then
      let left_spaces_len=(maxlen-${#line})/2
    fi
    let right_spaces_len=maxlen-${#line}-left_spaces_len
    leftspaces=${box_mid_center:0:$left_spaces_len}
    rightspaces=${box_mid_center:0:$right_spaces_len}
    boxed_line="${ml}${mc}${leftspaces}${line}${rightspaces}${mc}${mr}"
    echo "$boxed_line"
  done
  echo "$box_bot"
}

#
# ----------------------------- Git ---------------------------------
#
function is_git_dir()
{
  status_result=$(git status &>/dev/null; echo $?)
  if [ $status_result -eq 0 -o $status_result -eq 1 ]; then
    echo "true"
  else
    echo "false"
  fi
}

function is_git_dirty()
{
  local git_status=$(git diff-index --name-only HEAD 2>/dev/null)
  if [ -z "$git_status" ]; then
    echo "false"
  else
    echo "true"
  fi
}

function git_branch_name()
{
  local branch_name=$(git name-rev --name-only HEAD 2>/dev/null)
  echo $branch_name
}

function git_dirty_display()
{
  local no_control_sequences="$1"
  local is_dirty=$(is_git_dirty)
  if [ "$is_dirty" = "true" ]; then
    if [ ! -z "$no_control_sequences" ]; then
      echo "(*)"
    else
      echo "${TERM_WHITE}(${TERM_RED}*${TERM_WHITE})"
    fi
  else
    if [ ! -z "$no_control_sequences" ]; then
      echo "( )"
    else
      echo "${TERM_WHITE}( )"
    fi
  fi
}

function git_info()
{
  local no_control_sequences="$1"

  if [ $(is_git_dir) = "true" ]; then
    local dirty=$(git_dirty_display $no_control_sequences)
    local branch=$(git_branch_name)
    
    if [ ! -z "$no_control_sequences" ]; then
      echo "${dirty} ${branch}"
    else
      echo "${dirty} ${TERM_GREEN}${branch}"
    fi
  else
    echo ""
  fi
}

