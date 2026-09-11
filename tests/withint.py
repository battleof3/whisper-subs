# Exec a command with SIGINT restored to default, like a terminal's foreground job gets.
import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
os.execvp(sys.argv[1], sys.argv[1:])
