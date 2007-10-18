#
# A collection of useful bash functions
#

#
#
# =========================== useful functions ==============================
#
#

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
	
	if [ -e "$thepath" ]; then
		eval export ${varname}=${thepath}
	fi
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
	find . -maxdepth $depth -type d | perl -ne ' $count = @matches = m/\//g; print "\t" x $count; print'
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

# ------------------------ Display ---------------------------------
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
# Usage: display_boxed [--centered] "line one" "line two" "etc."
#
#  Displays the given lines of text in pretty fashion, 
#  wrapped in a plus-and-pipe box. If --centered is
#  passed as the first argument, the lines will be centered
#  (otherwise, left-justified). Example:
#
# +--------------------------------------------+
# |             asdfasdfasdf fuhe              |
# |                  zanzibar                  |
# | fooeee oijef eijfe  efijejfejief efjiefj e |
# +--------------------------------------------+
#
#
#
function display_boxed()
{
   local dashes="-----------------------------------------------------------------------------------------------------------------------------"
   local spaces="                                                                                                                             "
   local centered=0
   if [ "$1" = "--centered" ]; then
      centered=1
      shift
   fi
   
   maxlen=$(length_of_longest_arg "$@")
   let innerwidth=maxlen+2
   longest_dashes=${dashes:0:$innerwidth}
   box_edges="+${longest_dashes}+"
   
   echo $box_edges
   for line in "$@"; do
      left_spaces_len=0
      if [ $centered -eq 1 ]; then
         let left_spaces_len=(maxlen-${#line})/2
      fi
      let right_spaces_len=maxlen-${#line}-left_spaces_len
      leftspaces=${spaces:0:$left_spaces_len}
      rightspaces=${spaces:0:$right_spaces_len}
      echo "| ${leftspaces}${line}${rightspaces} |"
   done
   echo $box_edges
}


# ----------------------------- ENV variables -----------------------
function set_env_vars_basic()
{
   export PLATFORM=$(uname -s)-$(uname -m | sed 's/ /_/g')
   export OS=$(uname -s)
   export HOST=`hostname | awk -F\. '{print $1}'`
}