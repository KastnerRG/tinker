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
# Filename: Board.py
# Version: 0.1 
# Description: Defines the Board object, which contains all of the methods
# necessary to create a custom board for the Altera OpenCL Compiler
# Author: Dustin Richmond

# Import Python Utilities
import xml.etree.ElementTree as ET, math
from collections import defaultdict, Counter
# Import Tinker Objects
import Memory, Tinker, IP

class Board(defaultdict):
    def __init__(self, version, board):
        p = Tinker.Tinker().get_board_xml(version, board)
        et = ET.parse(p)
        self.types = {}
        self.update(self.parse(et))
    def get_info(self):
        return self.info;
    
    # TODO: Integrate into the print function
    def print_info(self,l):
        print self
            
    # verify that the high level specification can be implemented on the board
    def verify(self, s):
        pass

    # Fill out the high level specification using defaults from the board
    def fill(self, s):
        pass
        
    def parse(self, et):
        r = et.getroot()
        d = self.__parse_board_elem(r)
        d.update(self.__parse_ip(r))
        return d

    def __parse_board_elem(self, e):
        d = defaultdict()
        # TODO: How do we handle verification/checking and mal-formed/missing errors?
        d["version"] = Tinker.parse_float(e,"version", ET.tostring)
        d["name"] = Tinker.parse_string(e,"name", ET.tostring)
        d["model"] = Tinker.parse_string(e,"model", ET.tostring)
        return d

    def __parse_ip(self, r):
        d = defaultdict()
        for (t, td) in self.__parse_ip_types(r):
            d.update(td)
        return d

    def __parse_ip_types(self, r):
        ts = set([e.tag for e in r.findall("./")])
        for t in ts:
            yield (t, self.__parse_ip_type(r, t))
                        
    def __parse_ip_type(self, r, t):
        d = defaultdict()
        d["IP"] = defaultdict()
        for te in r.findall("./%s" % t):
            ip = IP.construct(t, te)
            d["IP"][ip["type"]] = ip
        return d
    
