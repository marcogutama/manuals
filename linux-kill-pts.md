### Kill user tty/pts sessions in Linux

#### Commands

- `w`: show who is logged on and what they are doing
- `who`: show who is logged on
- `tty`: show current users pseudo terminal
- `ps -ft pts/1`: get process id for the pseudo terminal
- `pkill`: signal process based on name and other attributes

1. Check active users logged into the server with: `w`
```
 16:53:37 up 23:46,  2 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
ubuntu   pts/1    24.69.132.96     16:45    0.00s  0.04s  0.00s w
ubuntu   pts/2    24.69.132.96:S.0 16:35   16.00s  0.02s  0.02s /bin/bash
```
2. Get the PID (Process ID) of a connected terminal (tty) with: `ps -ft pts/1`
```
UID        PID  PPID  C STIME TTY          TIME CMD
ubuntu   28580 28102  0 16:45 pts/1    00:00:00 -bash
ubuntu   29081 28580  0 16:55 pts/1    00:00:00 ps -ft pts/1
```
3. Kill the process: `kill 28580`

4. If the process doesn’t gracefully terminate, just as a last option you can forcefully kill by sending a SIGKILL

# kill -9 

4. Alternatively use `pkill -9 -t pts/0`