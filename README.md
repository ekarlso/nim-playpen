Playpen for Nim-lang
====================

## Install deps

This is needed to build nim_playpen on the host and clone repo etc.

sudo yum install clang make systemd-devel glib2-devel glibc-devel binutils libseccomp-devel gcc git

## Clone repository

```git clone http://github.com/ekarlso/nim-playpen```

Change directory to nim-playpen

```cd nim-playpen```


## Build a chroot for a nim release

This builds the needed chroot that is required to run nim snippets in
isolation. This will install a chroot in a folder ~/versions/<version>.

```bash bin/build-release-jail.sh```


# Alternatives for process isolation

https://github.com/cms-dev/isolate/