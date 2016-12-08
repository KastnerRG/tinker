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
# Filename: Memory.py
# Version: 0.1 
# Description: Object that defines an entire abstract memory system inside of a
# Memory architecture
# Author: Dustin Richmond

import xml.etree.ElementTree as ET, math, abc, sys
from collections import Counter
import Tinker
from IP import IP, parse_list, parse_int

class Memory(IP):
    _C_LATENCY_RANGE= (1,1000)
    _C_PORT_TYPES = set(["r", "w", "rw"])
    _C_RESOURCE_RANGE= (0,10000)
    _C_CLOCK_RATIOS = []
    _C_RATIOS = set(["Full", "Half", "Quarter"])
    _C_ROLES = set(["primary", "secondary", "independent"])

    def __init__(self, e):
        """

        Construct a generic Memory object that encapsulates a IP object
        using the provided element tree.

        Arguments:

        e -- An element tree element containing the description of this
        Memory object
        
        """
        super(Memory, self).__init__(e)

    @classmethod
    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this IP

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        super(Memory,cls).validate(d)
        cls.check_resources(d)
        cls.check_latency(d)
        cls.check_ports(d)
    
    @classmethod
    def parse(cls, e):
        """
        Parse the description of this Memory object from an element tree
        element and return a dictionary with the parameters
        found.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        d = dict()
        d["resources"] = cls._parse_resources(e)
        d["latency"] = parse_int(e, "latency")
        d["ports"] = cls.parse_ports(e)
        d["ratios"] = cls.parse_ratios(e)
        d["roles"] = cls.parse_roles(e)
        return d
                
    def configure(self, d):
        """

        Configure this object according to a high level description
        fill in any missing defaults, and verify that the description
        can be implemented

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        super(Memory,self).configure(d)
        
    def verify(self):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        self.validate(self)

    @classmethod
    def check_ports(cls, d):
        ports = d.get("ports")
        if(ports is None):
            Tinker.key_error("ports", Tinker.tostr_dict(d))
        for p in ports:
            if(p not in cls._C_PORT_TYPES):
                Tinker.value_error_xml("ports", p, str(list(cls._C_PORT_TYPES)),
                                        Tinker.tostr_dict(d))

    @classmethod
    def _parse_resources(cls, e):
        d = Counter()
        for rt in cls._C_RESOURCE_TYPES:
            d[rt] = parse_int(e, rt)
        return d
    
    def get_macros(self,s):
        return []
    
    def get_resources(self):
        self.check_resources(self)
        return self["resources"]

    @classmethod
    def check_latency(cls, d):
        l = d.get("latency")
        l_min = cls._C_LATENCY_RANGE[0]
        l_max = cls._C_LATENCY_RANGE[1]
        if(l is None):
            Tinker.key_error("latency", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(l, l_min, l_max)):
            Tinker.value_error_map("latency", str(hex(l)),
                                   "Range(0x%x, 0x%x)" % (l_min, l_max),
                                    Tinker.tostr_dict(d))
    
    @classmethod
    def check_resources(cls, d):
        rs = d.get("resources")
        r_min = cls._C_RESOURCE_RANGE[0]
        r_max = cls._C_RESOURCE_RANGE[1]
        for rt in cls._C_RESOURCE_TYPES:
            r = rs.get(rt, None)
            if(r is None):
                Tinker.key_error(rt, Tinker.tostr_dict(d))
            if(not Tinker.is_in_range(r, r_min, r_max)):
                Tinker.value_error_map(rt, str(hex(r)),
                                       "Range(0x%x, 0x%x)" % (r_min, r_max),
                                       Tinker.tostr_dict(d))
    
    @classmethod
    def parse_ports(cls, e):
        mem_ports = parse_list(e,"ports")
        for mp in mem_ports:
            if(mp not in cls._C_PORT_TYPES):
                Tinker.value_error_xml("ports", mp, str(ports), ET.tostring(e))
        return mem_ports

    @classmethod
    def parse_ratios(cls, e):
        mem_ratios = parse_list(e, "ratios")
        for mr in mem_ratios:
            if(mr not in cls._C_RATIOS):
                Tinker.value_error_xml("ratios", mr, str(ratios), ET.tostring(e))
        return mem_ratios

    @classmethod
    def parse_roles(cls, e):
        roles = parse_list(e, "roles")
        for mr in roles:
            if(mr not in cls._C_ROLES):
                Tinker.value_error_xml("roles", mr, str(roles), ET.tostring(e))
        return roles

