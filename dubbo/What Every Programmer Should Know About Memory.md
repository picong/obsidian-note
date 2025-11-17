```ad-abstract
As CPU cores become both faster and more numerous, the limiting factor for most programs is now, and will be for some time, memory access. Hardwarte designers have come up with ever more sophisticated memory handling and acceleration techniques -- such as CPU caches--but these cannot work optimally without some help from the programmer. Unfortunately, neither the structure nor the cost of using the memory subsystem of a computer or the caches on CPUs is well understood by most programmers. This paper explains the structure of memory subsystems in use on modern commodity hardware, illustrating why CPU caches were developed, how they work, and what programs should do to achieve optimal performance by utilizing them.
```

# 1 Introduction
Todays these changes mainly come in the following forms:
- RAM hardware design (speed and parallelism).
- Memory controller designs.
- CPU caches.
- Direct memory access (DMA) for devices.

# 2  Commodity Hardware Today
![[Pasted image 20231013183822.png]]

This was done for performance reasons related to insufficiently fast connections between the Northbridge and Southbridge. However, today the PCI-E slots ate all connected to the Southbridge.
译:这样做是因为南桥和北桥之间的连接性能不够快。但是，现在PCI-E插槽全部连接到南桥。
Such a system structure has a number of noteworthy consequences:
- All data communication from one CPU to another must travel over the same bus used to communicate with the Northbridge.
- All communication with RAM must pass through the Northbridge.
- The RAM has only a single port.
- Communication between a CPU and a device attached to the Southbridge is routed through the Northbridge.
Two bottleneck:
- All communication with devices on either bridge had to pass through the CPU.(Solution: DMA allows devices, with the help of the Northbridge, to store and receive data in RAM directly without the intervention of the CPU.)
- The bus from the Northbridge to the RAM.

## 2.1 RAM Types
Why are there both static RAM (SRAM) and dynamic RAM (DRAM). The former is much faster and provides the same functionality.
SRAM is much more expensive to produce and to use than DRAM.

The important things to take away from this section are:
- there are reasons why not all memory is SRAM
- memory cells need to be individually selected to be used
- the number of address lines is directly responsible for the cost of the memory controller, motherboards, DRAM module, and DRAM chip
- it takes a while before the results of the read or write operation are available
SRAM is currently used in CPU caches and on-die where the connections are small and fully under control of the CPU designer.

The memory controller provides a clock, the frequency of which determines the speed of the Front Side Bus (FSB)

# 3 CPU Caches
```ad-note
Realizing that locality exists is key to the concept of CPU caches as we use them today.
```

![[Pasted image 20231017112236.png]]
In this figure we have two processors, each with two cores, each of which has two threads. The threads share the Level 1 caches. The cores (shaded in the darker gray) have individual Level 1 caches. All cores of the CPU share the higher-level caches. The two processors (the two big boxes shaded in the lighter gray) of course do not share any caches. All this will be important, especially when we are discussing the cache effects on multi-process and multi-thread applications.

By default all data read or written by the CPU cores is stored in the cache.
