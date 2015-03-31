# Description

The `retrymount` is similar to `mount -P`, but it doesn't try to hide
errors and fact of re-mounting from user, and so is 100% safe to use with
any applications/9P servers.

If some network error happens and mount point become unaccessible, your
application will get I/O error. At same time, retrymount will try to retry
same mount command again and again until success. So you application after
I/O error also can retry access to files on mount point until success.


# Install

Make directory with this app available in /opt/powerman/retrymount/, for ex.:

```
# git clone https://github.com/powerman/inferno-contrib-retrymount.git $INFERNO_ROOT/opt/powerman/retrymount
```

or in user home directory:

```
$ git clone https://github.com/powerman/inferno-contrib-retrymount.git $INFERNO_USER_HOME/opt/powerman/retrymount
$ emu
; bind opt /opt
```

If you want to run commands and read man pages without entering full path
to them (like `/opt/VENDOR/APP/dis/cmd/NAME`) you should also install and
use https://github.com/powerman/inferno-opt-setup 

## Dependencies

* https://github.com/powerman/inferno-contrib-logger


# Usage

```
; retrymount [... usual mount options ...]
```

