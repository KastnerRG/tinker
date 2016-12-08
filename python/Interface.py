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
# Filename: Interfaces.py
# Description: An Interface object represents the OpenCL Interfaces in a
# Board Support Package. An Interface is a collection of configured IP.
# available on the board
# Author: Dustin Richmond

import abc, sys
import Tinker
from collections import Counter
class Interface(dict):
    _C_INTERFACE_TYPES = ["GlobalMemory", "Host", "Kernel"]
    _C_INTERFACE_QUANTITY_RANGE = (1, 10)
    def __init__(self, desc):
        """Construct a generic Interface Object

        Arguments:

        desc -- a description object enumerating the attributes of this
        interface

        """
        d = self.parse(desc)
        self.validate(d)
        self.update(d)

    
    @classmethod
    def parse(cls, desc):
        """
        
        Parse the description of this IP object from an dictionary
        return a dictionary built from the key-value pairs.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        d = {}
        cls.parse_keys(desc)
        d["type"] = cls.parse_type(desc)
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
        cls.check_type(d)


    def implement(self, b):
        """

        Implement this object using the IP provided by a board object

        Arguments:

        b -- A Board object, containing parsed description of a custom
        board
        
        """
        self.validate(d)
        pass

    def __fill(self, d):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        pass

    def verify(self):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """

    @classmethod        
    def check_type(cls, d):
        cls.parse_type(d)
    
    @classmethod
    def parse_type(cls, desc):
        t = parse_string(desc,"type")
        if(t not in cls._C_INTERFACE_TYPES):
            Tinker.value_error_map("type", str(t), str(cls._C_INTERFACE_TYPES),
                               Tinker.tostr_dict(desc))
        return t
    
    @classmethod
    def parse_role(cls, desc):
        r = parse_string(desc, "role")
        if(r not in cls._C_INTERFACE_ROLES):
            Tinker.value_error_map("role", str(r), str(cls._C_INTERFACE_ROLES),
                               Tinker.tostr_dict(desc))
        return r

    @classmethod
    def check_role(cls, d):
        cls.parse_role(d)
        
    @classmethod
    def parse_quantity(cls,d):
        q = parse_int(d, "quantity")
        if(q < 0):
            Tinker.value_error_map("quantity",str(q),"Non-negative Integers",
                                   Tinker.tostr_dict(d))
        return q

    @classmethod
    def check_quantity(cls,d):
        q = parse_int(d, "quantity")
        if(not Tinker.is_in_range(q,
                                  cls._C_INTERFACE_QUANTITY_RANGE[0],
                                  cls._C_INTERFACE_QUANTITY_RANGE[1])):
            Tinker.value_error_map("quantity", str(q),
                                   "range(%d, %d)"
                                   % (cls._C_INTERFACE_QUANTITY_RANGE[0],
                                      cls._C_INTERFACE_QUANTITY_RANGE[1]),
                                      Tinker.tostr_dict(d))
            
    @classmethod
    def parse_keys(cls,desc):
        k = set(desc.keys())
        if("interfaces" not in desc):
            ifs = set([])
        else:
            ifs = set(cls.parse_interfaces(desc))
        err = (k - ifs - cls._C_INTERFACE_KEYS)
        if(err != set()):
            print "In description:"
            Tinker.print_description(desc)
            sys.exit("Error! Unknown keys: %s" % str(list(err)))
        return k | ifs
    
    def get_pin_elements(self, version, verbose):
        return []
        
    def get_global_mem_elements(self, version, verbose):
        return []
        
    def get_interface_elements(self, version, verbose):
        return []
    
    def get_host_elements(self, version, verbose):
        return []

    def get_macros(self, version, verbose):
        return []
    
    def get_resources(self, version, verbose):
        r = Counter({"alms":0, "ffs":0, "rams":0, "dsps":0})
        return r

def parse_list(d, k):
    l = d.get(k)
    if(l is None):
        Tinker.key_error(k, Tinker.tostr_dict(d))
    elif(not Tinker.is_list(l)):
        Tinker.value_error_map(k, l, "Lists", Tinker.tostr_dict(d))
    return l

def parse_dict(d, k):
    dct = d.get(k)
    if(dct is None):
        Tinker.key_error(k, Tinker.tostr_dict(d))
    elif(not Tinker.is_dict(dct)):
        Tinker.value_error_map(k, dct, "Dictionary", Tinker.tostr_dict(d))
    return dct

def parse_string(d, k):
    s = d.get(k)
    if(s is None):
        Tinker.key_error(k, Tinker.tostr_dict(d))
    elif(not Tinker.is_string(s)):
        Tinker.value_error_map(k, s, "Strings", Tinker.tostr_dict(d))
    return s

def parse_int(d, k):
    i = d.get(k)
    if(i is None):
        Tinker.key_error(k, Tinker.tostr_dict(d))
    try:
        return int(i)
    except ValueError:
        Tinker.value_error_map(k, i, "Integers", Tinker.tostr_dict(d))

def construct(t):
    import GlobalMemoryInterface, HostInterface, KernelInterface
    if(t == "GlobalMemory"):
        return GlobalMemoryInterface.GlobalMemoryInterface
    elif(t == "Host"):
        return HostInterface.HostInterface
    elif(t == "Kernel"):
        return KernelInterface.KernelInterface
    else:
        Tinker.value_error("interfaces", str(t), str(Interface._C_INTERFACE_TYPES))
    
