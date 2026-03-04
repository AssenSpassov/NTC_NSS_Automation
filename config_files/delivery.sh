#!/bin/bash

# this file needs to be present in the ~/ folder for the respetive user
# and is aliased to just delivery in the ~/.aliases file, although it
# will also work if invoked directly

print_help_short(){
echo "
This is a script to ensure you can always connect to your existing tmux session
or properly create a new one.
Here is a quick cheat sheet of tmux commands:
        tmux ls --> list active tmux sessions
        tmux a --> attach to the last active session
        tmux a -t SESSION_NAME --> attach to a specific tmux session.
                The SESSION_NAME can be obtained from the 'tmux ls' output.

To start a new session with the correct naming of Windows and tabs, do the command
with the following syntax:
	delivery clustername1-studen1student2 clustername2-student1-student2 ...

On next starts you can do just 'delivery' and you will get presented with the option
to connect to your existing session.

Connectivity to the clusters (works outside of the tmux as well):
        c = connect to the cluster noted in the prompt
        c CLUSTERNAME = connect to the cluster specified with CLUSTERNAME
        cvm X = connect to the CVM number X in the cluster specified in the prompt
        nhost X = connect as user nutanix to the host number X in the cluster
        rhost X = connect as user root to the host number X in the cluster
        pc = connect to the PC for the cluster specified in the prompt
"
}

print_help_long(){

	print_help_short
	echo "
Once you are in tmux there are multiple options. Here are are the most common ones:
	Ctrl+b d --> detach from current session
	Ctrl+b c --> Create new window
	Ctrl+b 0-9 --> move between windows 0 to 9
	Ctrl+b n --> move to next window
	Ctrl+b p --> move to previous window
	Ctrl+b alt+\" --> split the current pane vertically
	Ctrl+b % --> split the current pane horizontally
		Rearramgement of panes can be tricky. Play with the following options:
		Ctrl+b SPACE; Ctrl+b Alt+{1-5}; Assen's choice: Ctrl+b Alt+5
	Ctrl+b ARROW --> move between panes in the direction of pressed arrow
		Also possible with just alt+ARROW
	Ctrl+b e --> toggle pane synchronization (you type something in the active
		pane, and it gets typed in the other panes as well. Does not apply
		if the current pane is maximized <- see next shortcut)
	Ctrl+b z --> toggle between full screen pane and back to its normal size
		(there is a capital letter Z next to the window name if we have
		a maximized pane in the respective window)
	Ctrl+b , --> this rename the current window
	Ctrl+b PgUp/PgDown --> scrol back in the console buffer for the active pane
		Press Ctrl+s to search in the pane's text/output
			n for next result
			Shift+n for previous result
			To start reverse search it is Ctrl+r
		Press q to get out of that mode and return to prompt
		NOTE: Those bindings can be switched to vi type if you are more familiar with it:
			Ctrl+b : set-window-option -g mode-keys vi
			This can be added to the tmux.conf file for each user
	Ctrl+b : --> brings us to tmux command prompt where tmux settings can be changed 

Most of the above tmux commands have long versions or verbose writting in the tmux command prompt,
e.g. 'tmux list-sessions'.
For more details please refer to the man page of tmux - 'man tmux'.

Or the following resource (there is a part two linked on this page):
	https://blog.hawkhost.com/2010/06/28/tmux-the-terminal-multiplexer/
"
}

while test -n $1 ; do
        case "$1" in
                --help|-h|help)
                print_help_long
                exit
                ;;
        *)
                print_help_short
		break
                ;;
        esac
        shift
done


echo "Currenlty running tmux sessions:"
	sessions_short=`tmux ls | awk -F\: '{print $1}'`
	sessions_long=`tmux ls`
	num_sessions=`tmux ls | wc -l`
	echo "	"$sessions_short
	echo "Full details:"
	echo $sessions_long | awk -F] '{ for(i=1;i<=NF;i++) print "\t"$i  }'
echo 

echo -n "Please enter your tmux-session name
	(a new session will be created, if not an existing name is provided): "
read session_name

if  [ -z $session_name ] ; then
	echo "Specifying new or existing session name is mandatory"
	exit 1;
fi

tmux ls | grep $session_name >> /dev/null
if [ $? -eq 0 ] ; then
	echo "A session with name '$session_name' already exists. Attaching to it..."
	tmux a -t $session_name
	exit 0;
fi

echo "There is no session with name '$session_name'. Creating a new one..."
tmux new-session -d -s $session_name


if [ ! -z $1 ] ; then
	for cluster in $@ 
	do
		echo Adding window for cluster $cluster
		tmux new-window -t $session_name -n $cluster
		cls=`echo $cluster | awk -F\- '{print $1}'`
		tmux send-key -t $session_name:$cluster "${cls}" Enter
	done
fi

i=0
tmux select-window -t $session_name:0
if [ ! -z $1 ] ; then
        for cluster in $@
        do
		cls=`echo $cluster | awk -F\- '{print $1}'`
		echo Splitting first window for cluster $cluster
                tmux split-window $split
                tmux send-key -t $session_name:0.$i "${cls}" Enter
		# the below if statement makes sure we open only as many panes in the first window as we have clusters
		# +1 though; since for some reason otherwise the last pane does not get its cluster populated
		if [ $i -eq $(( $# -1 )) ] ; then
			break
		fi
		i=$(( $i + 1 )) # $i needs to be incremented here in order to not screw the indexes
        done

	# The below two lines are supposed to arrange the panes in the first window
	# but for some reason are sent directly to the shell and do not result in 
	# proper arrangement (see: https://newbedev.com/how-to-auto-resize-panes-in-tmux )
	# need to figure out how to send them properlu to the window in order to not need
	# manual intervention
	#tmux send-key -t $session_name:0 C-b
	#tmux send-key -t $session_name:0 M-5
fi

tmux rename-window -t 0 All
tmux -2 attach-session -t $session_name
