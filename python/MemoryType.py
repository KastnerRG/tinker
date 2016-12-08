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

import xml.etree.ElementTree as ET
import Tinker, Memory
from IP import parse_list, parse_string, findsingle

class MemoryType(dict):
    _C_KNOWN_TYPES = set(["DDR3", "QDRII", "LOCAL"])
    def __init__(self, e):
        """

        Construct a generic MemoryType object that encapsulates a IP object
        using the provided element tree.

        Arguments:

        e -- An element tree element containing the description of this
        MemoryType object
        
        """
        d = self.__parse(e)
        self.__validate(d)
        self.update(d)
        
    def __parse_type(self, t, e):
        d = dict()
        d["interfaces"] = parse_list(e,"interfaces")
        d["default"] = parse_string(e, "default")
        for i in d["interfaces"]:
            ie = findsingle(e, "./phy/[@id='%s']" % str(i))
            m = self.__construct(t, ie)
            d[i] = m
        return d

    def __parse(self, e):
        d = dict()
        d["type"] = "memory"
        d["types"] = parse_list(e,"types")
        for t in d["types"]:
            te = findsingle(e, "./%s" % t)
            if(t not in self._C_KNOWN_TYPES):
                Tinker.value_error_xml("types", t,
                                       str(list(self._C_KNOWN_TYPES)),
                                       ET.tostring(e))
            d[t] = self.__parse_type(t, te)
        return d
    
    def __validate(self, d):
        self.__check_types(d)
        self.__check_defaults(d)
        self.__check_interfaces(d)
        
    def __check_types(self, d):
        ts = d.get("types")
        if(ts is None):
            Tinker.key_error("types", Tinker.tostr_dict(d))
        for t in ts:
            if(t not in self._C_KNOWN_TYPES):
                Tinker.value_error_map("types", t,
                                       str(self._C_KNOWN_TYPES),
                                       Tinker.tostr_dict(d))
                
    def __check_defaults(self, d):
        self.__check_types(d)
        ts = d["types"]
        for t in ts:
            dt = d[t]
            default = dt.get("default")
            if(default is None):
                Tinker.key_error("default", Tinker.tostr_dict(dt))
            if(default not in dt.keys()):
                Tinker.value_error_map("default", default, str(list(dt.keys())),
                                       Tinker.tostr_dict(dt))
                
    def __check_interfaces(self, d):
        self.__check_types(d)
        ts = d["types"]
        for t in ts:
            dt = d[t]
            interfaces = dt.get("interfaces")
            if(interfaces is None):
               Tinker.key_error("interfaces", Tinker.tostr_dict(dt))
            for i in interfaces:
                if(not Tinker.is_id(i)):
                    value_error_map("interfaces", i, "Alphbetic Strings",
                                     Tinker.tostr_dict(dt))
    def __construct(self, t, e):
        if(t == "DDR3"):
            import DDR
            return DDR.DDR(e)
        elif(t == "QDRII"):
            import QDR
            return QDR.QDR(e)
        elif(t == "LOCAL"):
            import LOCAL
            return LOCAL.LOCAL(e)
