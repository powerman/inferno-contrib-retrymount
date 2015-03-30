The `retrymount` is similar to `mount -P`, but it doesn't try to hide errors and fact of re-mounting from user, and so is 100% safe to use with any applications/9P servers.

If some network error happens and mount point become unaccessible, your application will get I/O error. At same time, retrymount will try to retry same mount command again and again until success. So you application after I/O error also can retry access to files on mount point until success.

Dependencies:
  * http://code.google.com/p/inferno-contrib-logger/


---


To install make directory with this module available in /opt/powerman/retrymount/, for ex.:

```
# hg clone https://inferno-contrib-retrymount.googlecode.com/hg/ $INFERNO_ROOT/opt/powerman/retrymount
```

or in user home directory:

```
$ hg clone https://inferno-contrib-retrymount.googlecode.com/hg/ $INFERNO_USER_HOME/opt/powerman/retrymount
$ emu
; bind opt /opt
```


---


Usage:

```
; retrymount [... usual mount options ...]
```