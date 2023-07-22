# docker-archive

This is an utility to transfer docker images to a StarlingX VM. It is targeted to StarlingX developers.

It is useful:

- for offline installs;
- to speed up the bootstrap phase;
- and to prevent for failures due to missing images.

The script save-arquive.sh saves docker images on the docker-archive server, according to a specified list of images. A remote server address can be optionally given. If omitted, the docker images are saved on the current machine.

A few image list templates are provided in this repo. The lists can be edited according to the users need.

The script load-archive.sh uploads images in StarlingX VM, according to a specified list of images, provided as input file. A remote server address can be optionally given. If omitted, the docker images are loaded from the current machine. A target server address can be optionally given. If omitted, the docker images are loaded onto a StarlingX VM hosted on the current machine. The images must be previously stored in the docker-arquive server, by script save-arquive.sh

An optional port number may be used in load-archive.sh, for the scenarios that a target VM is accessible via port-forward. Refer to the examples below.


## Install

Clone this repository, and add the following environment variable in your .bashrc

export STXPASSWD=<StarlingX VM Password>


## save-archive examples:

- Save archive in localhost

```
    $ ./save-archive.sh --image-list lists/stx-8.0.lst
```

- Save archive in remote server

```
    $ ./save-archive.sh --image-list lists/stx-8.0.lst --server $USER@<remote ip addr>
```


## load-archive examples:

- Load archive from logged VM

```
    $ ./load-archive.sh --image-list lists/stx-8.0.lst --server $USER@<remote ip addr>
```

- Load archive from localhost into target VM

```
    $ ./load-archive.sh --image-list lists/stx-8.0.lst --target sysadmin@10.10.10.2
```

- Load archive from localhost into target VM using a port number

```
    $ ./load-archive.sh --image-list lists/stx-8.0.lst --target sysadmin@localhost:10100
```

- Load archive from remote server into target VM (when logged in VM host machine)

```
    $ ./load-archive.sh --image-list lists/stx-8.0.lst --server $USER@<remote ip addr> --target sysadmin@10.10.10.2
```

- Load archive from remote server into target VM using a port number (when logged in any remote machine)

```
    $ ./load-archive.sh --image-list lists/stx-8.0.lst --server $USER@<remote ip addr> --target sysadmin@<remote ip addr>:10100
```
