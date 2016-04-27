# Tinker: Generating Custom Memory Architectures for Altera’s OpenCL Compiler

Tools for C/C++ based-hardware development have grown in popularity in recent
years. However, the impact of these tools has been limited by their lack of
support for integration with vendor IP, external memories, and communication
peripherals. Thus, we have created Tinker! Tinker is an open source Board
Support Package generator for Altera’s OpenCL Compiler. Board Support Packages
define memory, communication, and IP ports for easy integration with high level
synthesis cores. Tinker abstracts the low-level hardware details of hardware
development when creating board support packages and greatly increases the
flexibility of OpenCL development. Tinker currently generates custom memory
architectures from user specifications.

The Tinker project is a collection of python scripts that turn high level
specifications (written in JSON) into XML files that are used by, Qsys, and TCL
scripts. Example specifications can be found in the example folder; Test kernels
can be found in the tests folder; Python and tcl scripts are locaed in their
respective folders. Documentation for this project being actively added to the
docs folder.

We currently support (and have tested) the following boards:

   Terasic de5net (a7) in Quartus 14.1

Tinker is released under an open source BSD-3 Clause license. You are free to
modify, use, and redistribute as long as it follows the guidelines setforth in
the LICENSE file.




