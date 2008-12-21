. "$HOME/.bashrc"

function setup_login_shell()
{
   # ----------------- Shell options ------------------
   shopt -s histappend

   # ----------------- Termcap  -----------------
   if [ "$TERM" != "screen" ]; then
	   if [ "$LAUNCHING_APP" = "terminator" ]; then
		   export TERM="ansi"
		   export TERMINFO="$HOME/.terminfo"
	   else
		   export TERM="xterm-color"
	   fi
   fi
   # export TERMINFO="$HOME/.terminfo"
   # export TERMCAP="$HOME/software/crossplatform/etc/termcap"

   # ----------------- Prompt  -----------------
   # Show 'root' in red
   if [ $UID = 0 ]; then
     TERM_BG_COLOR=${TERM_BG_RED}
   else
     TERM_BG_COLOR=${TERM_BG_BLUE}
   fi
   export PS1="# "
   export PROMPT_COMMAND='update_prompt'
   export PS2="#| "

   # ----------------- Command completion  -----------------
	source_if "$HOME/.bash_completion"
	source_if "$HOME/.bash_completion_svn"
	source_if "$HOME/external-software/crossplatform/etc/bash_completion_svk"
   # ignore .svn directories for path completion
   export FIGNORE=.svn 
   # ignore CVS directories for path completion
   export FIGNORE=$FIGNORE:CVS
   # after the command completion, reset manpath
   unset MANPATH

   # ----------------- Login greeting  -----------------
   # Where are we logged in from?
   if [ "$LOCALNESS" = "local" ]; then
   	LOCATION_MESSAGE="locally on $LAUNCHING_APP"
   else
   	LOCATION_MESSAGE="via ssh from $SSH_REMOTE_HOST"
   fi

   # print info about the shell environment
   if [ -z "$SHOWED_CONNECTION_INFO" ]; then
   	display_boxed --centered "Connected to $HOST $LOCATION_MESSAGE." "Platform is $PLATFORM."
   	export SHOWED_CONNECTION_INFO="yes"
   fi
	
   # if we're not already in screen, offer the opportunity
   #  to reattach to detached screens:
   local screen_path=$(which screen)
   if [ ! -z "$screen_path" ]; then
      if [ -z "$RUNNING_SCREEN" ]; then
      	detached_screens=$(screen -list | awk '/Detached/ {print $1}' )
      	if [ ! -z "$detached_screens" ]; then
      		head1="Detached screens available: "
      		head2=" "
      		tail1=" "
      		tail2=" Type 'screen -r <name>' to reattach."
      		display_boxed  --centered "$head1" "$head2" $detached_screens "$tail1" "$tail2"
      	fi
      fi
   fi

}

# do the login stuff only for interactive shells:
if [ ! -z "$PS1" ]; then
   setup_login_shell

	#
	# if a custom bash is available, run that instead
	#
	#  (but only if we're not *already* running that custom shell)
	custom_shell="$HOME/external-software/$PLATFORM/bin/bash"

	if [ -e "$custom_shell" -a "$0" != "$custom_shell" -a -z "$SHOWED_CUSTOM_SHELL_MESSAGE" ]; then
		export SHOWED_CUSTOM_SHELL_MESSAGE="yes"
		echo "Running custom bash shell from $custom_shell"
    # Do host-specific changes
    source_if "$HOME/.bashrc.${HOST}"
		exec "$custom_shell"
	fi
fi
