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
# Filename: Description.py
# Version: 0.1 
# Description: Encapsulates a high-level board description, as specified
# by a user in JSON format. 
# Author: Dustin Richmond

import json, sys
from collections import defaultdict
import Interface, GlobalMemoryInterface, Tinker
from collections import Counter
class Description(dict):
    _C_DESCRIPTION_KEYS = set(["name", "interfaces"])
    def __init__(self, depath, board):
        """Construct a Description Object

        Arguments:

        depath -- Path of the JSON description to be parsed. Throws an
        IOError if file is not found
        
        """
        # TODO: Catch the IOError
        fp = open(depath)
        # TODO: Catch malformed error
        d = json.load(fp)
        d = self.parse(d)
        self.validate(d)
        self.update(d)
        self.__b = board
        self.implement(board)
        
    @classmethod
    def parse(cls, desc):
        """
        
        Parse the description of this IP object from a dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        d -- A dictionary with the parameters for this Description object
        
        """
        d = dict()
        cls.parse_keys(desc)
        n = cls.parse_name(desc)
        d["name"] = n
        ifs = cls.parse_interfaces(desc)
        d["interfaces"] = ifs
        for i in ifs:
            d[i] = Interface.construct(i)(desc[i])
        if("Kernel" not in ifs):
            ifs.append("Kernel")
            d["Kernel"] = Interface.construct("Kernel")({"type":"Kernel"})

        if("Host" not in ifs):
            ifs.append("Host")
            d["Host"] = Interface.construct("Host")({"type":"Host"})
        return d

    def validate(self, d):
        """

        Validate the parameters of a Description object

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """

    def implement(self, b):
        """

        Implement this object using the IP provided by a board object

        Arguments:

        b -- A Board object, containing parsed description of a custom
        board
        
        """
        self.validate(self)
        for i in self["interfaces"]:
            self[i].implement(b["IP"])
        self.__configure()
        self.verify()

    def get_global_mem_elements(self, version, verbose):
        self.verify()
        l = []
        for i in self["interfaces"]:
            l += self[i].get_global_mem_elements(version, verbose)
        return l
            
    def get_resources(self, version, verbose):
        self.verify()
        r = Counter({"alms":0, "ffs":0, "rams":0, "dsps":0})
        for i in self["interfaces"]:
            ri = self[i].get_resources(version, verbose)
            r =  r + ri
            
        return Counter({"alms":0, "ffs":0, "rams":0, "dsps":0})
            
    def get_interface_elements(self, version, verbose):
        self.verify()
        l = []
        for i in self["interfaces"]:
            l += self[i].get_interface_elements(version, verbose)
        return l
                
    def get_host_elements(self, version, verbose):
        self.verify()
        l = []
        for i in self["interfaces"]:
            l += self[i].get_host_elements(version, verbose)
        return l
            
    def get_pin_elements(self, version, verbose):
        # TODO: Get version from board
        self.verify()
        l = []
        for i in self["interfaces"]:
            l += self[i].get_pin_elements(version, verbose)
        return l

    def get_macros(self, version, verbose):
        l = []
        for i in self["interfaces"]:
            l += self[i].get_macros(version, verbose)
        return l
    
    def __configure(self):
        """

        Perform any final, object-specific configurations during implementation


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        
    def verify(self):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        for i in self["interfaces"]:
            self[i].verify()
        # TODO: Verify top-level
        pass
    
    def validate(self, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this Interface

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        pass

    @classmethod
    def parse_name(cls, d):
        n = d.get("name", None)
        #TODO: Verify name
        return n

    @classmethod
    def parse_keys(cls,desc):
        k = set(desc.keys())
        ifs = set(cls.parse_interfaces(desc))
        err = (k - ifs - cls._C_DESCRIPTION_KEYS)
        if(err != set()):
            print "In description:"
            Tinker.print_description(desc)
            sys.exit("Error! Unknown keys: %s" % str(list(err)))
        return k | ifs

    @classmethod
    def parse_interfaces(cls, d):
        ifs = d.get("interfaces",None)
        if(ifs is None):
            Tinker.key_error("interfaces",str(d))
        if(isinstance(ifs, basestring)):
            print "In description:"
            Tinker.print_description(d)
            Tinker.value_error("interfaces", str(ifs), "List")
        for i in ifs:
            if(ifs.count(i) > 1):
                sys.exit("Error! Interface \"%s\" was not unique in list %s"
                         % (i, str(ifs)))
            if(d.get(i,None) is None):
                Tinker.key_error(i,str(d))
        return ifs

    
