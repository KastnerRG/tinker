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
# Filename: IP.py
# Version: 0.1 
# Description: Defines the IP object, which is anything that has resources
# in an OpenCL Board Support Package
# Author: Dustin Richmond

# Import Python Utilities
import xml.etree.ElementTree as ET
from collections import defaultdict
from Resources import Resources
import abc
import Tinker

class IP(dict):
    def __init__(self, e):
        """
        Construct a generic IP object that encapsulates a dictionary
        
        Arguments:

        e -- An element tree element containing the description of this
        object

        """
        d = self.parse(e)
        self.validate(d)
        self.update(d)

    @abc.abstractmethod
    def parse(cls, e):
        """
        Parse the description of this IP object from an element tree
        element and return a defaultdictionary with the parameters
        found.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """

    @classmethod
    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this IP

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        pass

    # Methods called when creating a specification
    @abc.abstractmethod
    def apply(self, e):
        pass

    @abc.abstractmethod
    def fill(self, d):
        pass

    @abc.abstractmethod
    def verify(cls, d):
        """

        Check a user-description to ensure that this IP object can
        implement the desired settings.

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        pass

    @abc.abstractmethod
    def get_interface(self,s): # TODO: interfaceS?
        pass

    @abc.abstractmethod
    def get_macros(self,s):
        pass

def construct(cls, e):
    import Memory
    return Memory.Memory(e)
    
def parse_string(e, k):
    s = e.get(k)
    if(s is None):
        Tinker.key_error(k, ET.tostring(e))
    elif(not Tinker.is_string(s)):
        Tinker.value_error_xml(k, s, "Strings", ET.tostring(e))
    return s

def parse_float(e, key):
    s = parse_string(e, key)
    try:
        return float(s)
    except ValueError:
        Tinker.value_error_xml(ks, s, "Real Numbers", ET.tostring(e))

def parse_int(e, key):
    s = parse_string(e, key)
    try:
        return int(s)
    except ValueError:
        Tinker.value_error_xml(ks, s, "Integers", ET.tostring(e))

def parse_list_from_string(s):
    return [e.strip() for e in s.split(",")]
        
def parse_list(e, key):
    s = parse_string(e, key)
    return [e.strip() for e in s.split(",")]
        
def parse_id(e):
    id = parse_string(e, "id")
    if(not Tinker.is_alphachar(id)):
        value_error_xml("id", id, "Alphanumeric Characters", ET.tostring(e))
    return id

def parse_ids(e):
    ids = parse_list(e,"ids")
    for id in ids:
        if(not Tinker.is_alphachar(id)):
            value_error_xml("ids", id, "Alphanumeric Characters", ET.tostring(e))
    return ids

def parse_macros(e):
    macros = parse_list(e, "macros")
    for m in macros:
        if(not Tinker.is_valid_verilog_name(m)):
            Tinker.value_error_xml("macros", m, "Valid Verilog Names",
                                   ET.tostring(e))
    return macros
