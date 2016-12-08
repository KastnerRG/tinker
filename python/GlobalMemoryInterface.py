# ----------------------------------------------------------------------
# Copyright (c) 2016, The Regents of the University of California All
# rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#
#     * Neither the name of The Regents of the University of California
#       nor the names of its contributors may be used to endorse or
#       promote products derived from this software without specific
#       prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL REGENTS OF THE
# UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
# ----------------------------------------------------------------------
import xml.etree.ElementTree as ET
import DDR, QDR
import Tinker, GroupMemoryInterface
import sys
from Interface import *
class GlobalMemoryInterface(Interface):
    _C_INTERFACE_KEYS = set(["interfaces", "type"])
    _C_INTERFACE_TYPES = set(["DMA"])
    _C_INTERFACE_ROLES = set(["primary", "secondary"])
    _C_INTERFACE_SIZE_RANGE = (1<<17, 1<<64)
    def __init__(self, desc):
        """Construct a generic Interface Object

        Arguments:

        desc -- a dictionary object containing a description of this
        interface

        """
        super(GlobalMemoryInterface,self).__init__(desc)

    @classmethod
    def parse(cls, desc):
        """
        
        Parse the description of this IP object from an dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        d = super(GlobalMemoryInterface,cls).parse(desc)
        d["interfaces"] = cls.parse_interfaces(desc)
        d["quantity"] = cls.parse_quantity(desc)
        for i in d["interfaces"]:
            d[i] = GroupMemoryInterface.GroupMemoryInterface(desc[i], i)
        return d
            
    @classmethod
    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this Interface

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        super(GlobalMemoryInterface,cls).validate(d)
        cls.check_interfaces(d)
        cls.check_quantity(d)
        cls.check_roles(d)

    @classmethod
    def check_roles(cls, d):
        cls.check_interfaces(d)
        ifs = d["interfaces"]
        pid = None
        spec = (d[ifs[0]].get("role") != None)
        for i in ifs:
            r = d[i].get("role")
            if(r is None and spec is True):
                Tinker.key_error("role",str(d[i]))
            elif(r != None and spec is False):
                print "In description:"
                Tinker.print_description(d)
                sys.exit("Roles must be specified for all Memory Interfaces, or none of them.")
            elif(r != None and r not in cls._C_INTERFACE_ROLES):
                Tinker.value_error_map("role", str(r), str(cls._C_INTERFACE_ROLES),
                                       Tinker.tostr_dict())
            elif(r != None and r == "primary" and pid != None):
                print "In description:"
                Tinker.print_description(d)
                sys.exit("Error! Two primary interfaces \"%s\" and \"%s\" found."
                         % (pid, i))
            elif(r == "primary"):
               pid = i

    def implement(self, b):
        """

        Implement the Interface described by this object using the Board
        object describing the IP available on this board. 

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        self.validate(self)
        for i in self["interfaces"]:
            self[i].implement(b["memory"])
        self.__configure()

    def __configure(self):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        base = 0
        size = 0
        for i in self["interfaces"]:
            self[i].check_size(self[i])
            sz = self[i]["size"]
            size += sz
            rem = 0
            if(base % sz != 0):
                rem = sz - (base % sz)
            base += rem
            self[i].set_base_address(base)
            base += sz
            
        self["size"] = size

        # Default to min frequency to meet timing
        min_freq = None
        min_id = None
        size = 0
        # TODO: Names for Memory Interfaces (must be less than 32 char)
        # Must have at least 128 KB of memory
        for i in self["interfaces"]:
            self[i].check_frequency(self[i])
            f = self[i]["freq_mhz"]
            if(min_freq is None or f < min_freq):
                min_freq = f
                min_id = i
                
        n = 0
        for i in self["interfaces"]:
            if(i == min_id):
                self['primary'] = i
                self[i].set_role("primary")
                self[i].set_config_addr(0x18)
            else:
                self[i].set_role("secondary")
                self[i].set_config_addr(0x100 + n * 0x18)
                n +=1 
            
        #TODO: Configuration address

    def verify(self):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        self.check_interfaces(self)
        self.check_quantity(self)
        self.check_roles(self)
        self.check_size(self)

    @classmethod
    def check_size(cls, d):
        sz = d.get("size")
        sz_min = cls._C_INTERFACE_SIZE_RANGE[0]
        sz_max = cls._C_INTERFACE_SIZE_RANGE[1]
        if(sz is None):
            Tinker.key_error("size", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(sz, sz_min, sz_max)):
            Tinker.value_error_map("size", str(hex(sz)),
                                   "Range(0x%x, 0x%x)" % (sz_min, sz_max),
                                    Tinker.tostr_dict(d))

    @classmethod
    def parse_quantity(cls, desc):
        ifs = cls.parse_interfaces(desc)
        return len(ifs)
    
    @classmethod
    def parse_interfaces(cls, desc):
        ifs = parse_list(desc, "interfaces")
        if(ifs == []):
            print "In description:"
            Tinker.print_description(d)
            sys.exit("Error! A Global Memory must have more than one interface!")
            
        for i in ifs:
            if(ifs.count(i) > 1):
                sys.exit("Error! Interface \"%s\" was not unique in list %s"
                         % (i, str(ifs)))
            parse_dict(desc, i)
        return ifs

    @classmethod
    def check_quantity(cls, d):
        super(GlobalMemoryInterface,cls).check_quantity(d)
        
        cls.check_interfaces(d)
        ifs = cls.parse_interfaces(d)
        q = parse_int(d, "quantity")
        if(q != len(ifs)):
            Tinker.value_error_map("quantity",str(q),str(ifs),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_interfaces(cls,d):
        ifs = parse_list(d, "interfaces")
            
        if(ifs == []):
            print "In description:"
            Tinker.print_description(d)
            sys.exit("Error! A Global Memory must have more than one interface!")

        for i in ifs:
            if(ifs.count(i) > 1):
                sys.exit("Error! Interface \"%s\" was not unique in list %s"
                         % (i, str(ifs)))
            parse_dict(d,i)
            d[i].validate(d[i])

    def get_macros(self, version, verbose):
        l = []
        for i in self["interfaces"]:
            l += self[i].get_macros(version, verbose)
        return l
    
    def get_pin_elements(self, version, verbose):
        l = []
        for i in self["interfaces"]:
            l += self[i].get_pin_elements(version, verbose)
        return l
        
    def get_global_mem_elements(self, version, verbose):
        l = []
        for i in self["interfaces"]:
            l += [self[i].get_global_mem_element(version, verbose)]
        return l

    def get_interface_elements(self, version, verbose):
        pid = self["primary"]
        # TODO: Check primary
        return self[pid].get_interface_elements(version, verbose)
                
        # TODO: Else, Error
        
    def get_host_elements(self, version, verbose):
        return []
