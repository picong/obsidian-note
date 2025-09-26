## Hardware management
Still another responsibility for the kernel is hardware management. Any device that the Linux system must communicate with needs driver code inserted inside the kernel code. The driver code allows the kernel to pass data back and forth to the device, acting as an intermediary between applications and the hardware. Two methods are used for inserting device driver code in the Linux kernel:
- Drivers compiled in the kernel
- Driver modules added to the kernel
Previoudly, the only way to insert device driver code was to recompile the kernel. Each time you added a new device to the system, you had to recompile the kernel code. This process became even more inefficient as Linux kernels supported more hardware. Fortunately, Linux developers devised a better method to insert driver code into the running kernel.
Programmers developed the concept of kernel modules to allow you to insert driver code into a running kernel without having to recompile the kernel. Also, a kernel module could be removed from the kernel when the device was finished being used. This greatly simplified and expanded using hardware with Linux.
The Linux system indentifies hardware devices as special files, called device files. There are three classifications of device files:
- Character
- Block
- Network
Character device files are for devices that can handle data only one character at a time. Most types of modems and terminals are created as character files. Block files are for devices that can handle data in large blocks at a time, such as disk drives.
The network file types are used for devices that use packets to send and receive data.
The Linux kernel interfaces with each filesystem using the Virtual File System (VFS). This provides a standard interface for the kernel to communicate with any type of filesystem. VFS caches information in memory as each filesystem is mounted and used.
The GNU organization (GNU stands for GNU's Not Unit) developed a complete set of Unix utilities but had no kernel system to run them on. These utilities were developed under a software philosophy called open source software (OSS).
The concept of OSS allows programmers to develop software and then release it to the world with no licensing fees attached.
## The core GNU utilities
The GNU project was mainly designed for Unix system administrators to have a Unix-like environment available. This  focus resulted in the project porting many common Unix system command-line utilities. The core bundle of utilities supplied for Linux systems is called the coreutils package.
The GNU coreutils package consists of three parts:
- Utilities for handling files
- Utilities for manipulating text
- Utilites for managing processes
Each of these three main groups of utilites contains several 
The shell contains a set of internal commands that you use to control tasks such as copying files, moving files, renaming files, displaying the programs currently running on the system, and stopping programs running on the system.

## The X Window software
Two basic elements control your video environment -- the vedeo card in your PC and your monitor. To display fancy graphics on your computer, the Linux software needs to know how to talk to both of them. The X Window software is the core element in presenting graphics. During installation you may notice a time when the installation program scans your monitor for supported video modes. Sometimes this causes your monitor to go blank for a few seconds. 

## Accessing CLI via a Linux Console Terminal
In the early days of Linux, when you booted up your system you would see a login prompt on your monitor, and that's all. As mentioned earlier, this is called the Linux console. It was the only place you could enter commands for the system.
After logging into a virtual console, you are taken. The following sections describe common software packages that provide graphical terminal emulation.