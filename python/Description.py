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
class Description(dict):
    _C_DESCRIPTION_KEYS = set(["name", "interfaces"])
    def __init__(self, depath):
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
        
    @classmethod
    def parse(cls, d):
        """
        
        Parse the description of this IP object from a dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        d -- A dictionary with the parameters for this Description object
        
        """
        dp = dict()
        cls.parse_keys(d)
        n = cls.parse_name(d)
        dp["name"] = n
        ifs = cls.parse_interfaces(d)
        dp["interfaces"] = ifs
        for i in ifs:
            c = Interface.construct(i)
            dp[i] = c(d[i])
        return dp

    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this Interface

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        pass

    def gete(self, k):
        super(Description,self).get(k, None)
        ifs = self.get("interfaces",None)
        if(ifs is None):
            Tinker.key_error("interfaces",str(d))

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
