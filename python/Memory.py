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

# Import Python Utilities
import xml.etree.ElementTree as ET, math
from collections import defaultdict
# Import Tinker Objects
import Tinker
import abc, sys
from IP import parse_list, parse_string, IP, parse_id, parse_ids

class Memory(IP):
    _C_KNOWN_TYPES = set(["DDR3", "QDRII", "LOCAL"])
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
        # TODO: A lot more work needs to be done on validation of the board
        # dictionary
        pass
        
    @abc.abstractmethod
    def fill(cls, d):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        pass

    @abc.abstractmethod
    def verify(cls, d):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        pass

    @abc.abstractmethod
    def get_interface(self,s):
        pass
    
    @abc.abstractmethod
    def get_macros(self,s):
        pass


    @classmethod
    def parse(cls,e):
        d = dict()
        d["type"] = "memory"
        ts = cls.parse_types(e)
        for se in e.findall("./*"):
            t = se.tag
            if(t not in ts):
                Tinker.key_error(t, ET.tostring(e))
            td = cls.parse_type(t,se)
            d[t] = td
        d["types"] = ts
        return d
    
    @classmethod
    def parse_type(cls,t,e):
        d = dict()
        ids = parse_ids(e)
        ides = e.findall("phy")
        for ide in ides:
            pd = cls.construct(t, ide)
            id = pd["id"]
            if(id not in ids):
                Tinker.value_error_xml("id", id, str(ids), ET.tostring(ide))
            d[id] = pd
        default = parse_default(e)
        d["default"] = default
        return d

    @classmethod
    def validate_type(cls,d):
        check_default(d)

    @classmethod
    def construct(cls, t, e):
        if(t == "DDR3"):
            import DDR
            return DDR.DDR(e)
        elif(t == "QDRII"):
            import QDR
            return QDR.QDR(e)
        elif(t == "LOCAL"):
            import LOCAL
            return LOCAL.LOCAL(e)
        
    @classmethod
    def parse_types(cls,e):
        ts = parse_list(e,"types")
        for t in ts:
            if(t not in cls._C_KNOWN_TYPES):
                Tinker.value_error("Types", t, cls._C_KNOWN_TYPES, ET.tostring(e))
        return ts

def check_default(d):
    default = d["default"]
    if(default not in d.keys()):
        Tinker.key_error_xml("default", ET.tostring(e))
    
def parse_default(e):
    id = parse_string(e, "default")
    if(not Tinker.is_alphachar(id)): # TODO: Valid ID
        Tinker.value_error_xml("default", id, "Alphanumeric Characters",
                               ET.tostring(e))
    return id

def parse_ports(e):
    ports = ["r", "w", "rw"]
    mem_ports = parse_list(e,"ports")
    for mp in mem_ports:
        if(mp not in ports):
            Tinker.value_error_xml("ports", mp, str(ports), ET.tostring(e))
    return mem_ports

def parse_ratios(e):
    ratios = ["Quarter", "Half","Full"]
    mem_ratios = parse_list(e, "ratios")
    for mr in mem_ratios:
        if(mr not in ratios):
            Tinker.value_error_xml("ratios", mr, str(ratios), ET.tostring(e))
    return mem_ratios

def parse_roles(e):
    mem_roles = set(["primary", "secondary", "independent"])
    roles = parse_list(e, "roles")
    for mr in roles:
        if(mr not in mem_roles):
            Tinker.value_error_xml("roles", mr, str(roles), ET.tostring(e))
    return roles

def parse_grouping(e):
    ids = parse_list(e, "grouping")
    for id in ids:
        if(not Tinker.is_alphachar(id)): # TODO: Valid ID
            Tinker.value_error_xml("grouping", id, "Alphanumeric Characters",
                                   ET.tostring(e))
    return ids
