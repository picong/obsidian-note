## Looking into the Linux kernel
The kernel is primarily responsible for four main functions:
- System memory management
- Software program management
- Hardware management
- Filesystem management
The following sections explore each of these functions in more detail.

## System memory management
One of the primary functions of the operating system kernel is memory management. Not only does the kernel manage the physical memory available on the server, but it can also create and mange virtual memory, or memory that does not actually exist.
It does this by using space on the hard disk, called the swap space. The kernel swaps the contents of virtual memory locations back and forth from the swap space to the actual physical memory. This allows the system to think there is more memory available than what physically exists (shown in Figure 1-2).

The memory locations are grouped into blocks called pages. The kernel locates each page of memory in either the physical memory or the swap space. The kernel then maintains a table of the memory pages that indicates which pages are in physical memory and which pages are swapped out to disk.

The kernel keeps track of which memory pages are in use and automatically copies memory pages that have not been accessed for a period of time to the swap space area (called swapping out), even if other memory is available.

## Software program management
The Linux operating system calls a running program a process.
The kernel creates the first process, called the `init process`, to start all other processes on the system. when the kernel starts, it loads the `init process` into virtual memory. As the kernel starts each additional process, it gives the process a unique area in virtual memory to store the data and code that the process uses.
A few different types of  `init process` implementations are available in Linux, but these days the two most popular are:
- SysVinit: The `SysVinit(SysV)` initialization method, the original method used by Linux, was based on the Unix System V initialization method. Though it is not used by many Linux distributions these days, you still may find it around in older Linux distributions.
- Systemd: The `Systemd` initialization method, created in 2010, has become the most popular initialization and process management system used by Linux distributions.

You can combine GNU long parameters with either Unix- or BSD-style parameters to customize your display. One cool feature of GNU long parameters that we really like is the --forest parameter. 

## Linux Process Signals
| Signal | Name | Description |
| ---- | ---- | ---- |
| 1 | HUP | Hang up. |
| 2 | INT | Interrupt. |
| 3 | QUIT | Stop running. |
| 9 | Kill | Unconditionally terminate. |
| 11 | SEGV | Segment violation. |
| 17 | Stop | Stop uncontionally but don't terminate. |
| 18 | TSTP | Stop or pause but continue to run in backgroud. |
| 19 | CONT | Resume execution after STOP or TSTP. |

## The mount command
Oddly enough, the command used to mount media is called mount. By default, the mount command displays a list of media devices currently mounted on the system. However, the newer version of the kernel mounts lots of virtual filesystems for management purposes, besides your standard storage devices. This can make the default output of the mount command very cluttered and confusing. If you know the filesystem type used for your drive partitions, you can filter that out using `mount -t ext4`。
The `mount` command provides four pieces of information:
- The device filename of the media
- The mount point in the virtual directory where the media is mounted
- The filesystem type

The -o option allows you to mount the filesystem with a comma-separated list of additional options. The popular options to use are as follows:
- ro: Mount as read-only.
- rw: Mount as read-write
- user: Allow an ordinary user to mount the filesystem.
- check=none: Mount the filesystem without performing an integrity check.
- loop: Mount a file.
## The umount command
To remove a removable media, you should never just remove it from the system. Instead，you shuold always unmount it first.

The command used to unmount devices is umount (yes, there's no "n" in the command, which gets confusing sometimes). The format for the umount command is pretty simple: umount [directory | device]
The umount command gives you the choice of defining the media device by either its device location or its mounted directory name. If any program has a file open on a device, the system won't let you unmount it.

## Using the df/du command
Sometimes you need to see how much disk space is available on an individual device.

## The sort Command
```shell
sort -t ':' -k 3 -n /etc/passwd
文件中的内容按照 :进行划分，然后根据第三列的数字进行排序
```
