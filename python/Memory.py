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
import IP, Tinker
import abc, sys

class Memory(IP.IP):
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
        return
        
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

    def parse(self,e):
        d = defaultdict()
        d["type"] = "memory"
        ts = parse_types(e)
        for se in e.findall("./*"):
            t = se.tag
            if(t not in ts):
                sys.exit("Memory Type \"%s\" from subelement tag not found in types attribute of parent element:\n %s"
                         % (t, ET.tostring(e)))                
            td = self.parse_type(t,se)
            self.validate_type(td)
            d[t] = td
        self.validate(d)
        return d
    
    def parse_type(self,t,e):
        d = defaultdict()
        ids = parse_ids(e)
        ides = e.findall("phy")
        for ide in ides:
            pd = self.construct(t, ide)
            id = pd["id"]
            if(id not in ids):
                sys.exit("Unknown ID \"%s\" found while parsing element:\n %s"
                         % (id, ET.tostring(ide)))
            d[id] = pd
        default = parse_default(e)
        d["default"] = default
        return d
    
    def validate_type(self,d):
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

def parse_types(e):
    return Tinker.parse_list_from_string(Tinker.parse_string(e,"types", ET.tostring))

def parse_ids(e):
    s = Tinker.parse_string(e,"ids", ET.tostring)
    ids = Tinker.parse_list_from_string(s)
    for id in ids:
        if(not Tinker.is_alphachar(id)):
            sys.exit("Invalid ID \"%s\" found in ids attribute:\n %s" % (id, ET.tostring(e)))
    return ids

def check_default(d):
    default = d["default"]
    if(default not in d.keys()):
        sys.exit("Invalid Default ID \"%s\" not found in list of ids %s from element:\n %s"
                 % (default, list(d.keys()), ET.tostring(e)))
    
def parse_default(e):
    id = Tinker.parse_string(e, "default", ET.tostring)
    if(not Tinker.is_alphachar(id)):
        sys.exit("Invalid Default ID \"%s\" found in id attribute:\n %s" % (id, ET.tostring(e)))
    return id
