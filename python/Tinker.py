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
# Filename: Tinker.py
# Version: 0.1 
# Description: A collection of utility methods, and the Tinker class that
# encapsulates the environment necessary to run the tinker script and generate
# the custom board-support package necessary for the Altera OpenCL Compiler
# Author: Dustin Richmond
import xml.etree.ElementTree as ET, math, os
from xml.dom import minidom
import sys, re, json

def prettify(elem):
    rough_string = ET.tostring(elem, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")

def clog2(i):
    return math.floor(math.log(i)/math.log(2))

def ratio2float(ratio):
    if(ratio =="Full"):
        return 1
    if(ratio =="Half"):
        return .5
    if(ratio =="Quarter"):
        return .25

def int2ratio(i):
    if(i == 1):
        return "Full"
    if(i == 2):
        return "Half"
    if(i == 4):
        return "Quarter"
    return "Invalid"

def check_var(v):
    if(v not in os.environ):
        sys.exit("ERROR: Environment Variable %s not set" % v)

def check_env():
    check_var("TCLXML_PATH")
    check_var("TINKER_PATH")

def check_path(p):
    if(not os.path.exists(p)):
        sys.exit("ERROR: Path %s does not exist" % p)

class Tinker():
    def __init__(self):
        check_env()
        self.path = os.path.expandvars("${TINKER_PATH}") + "/"
        check_path(self.path)
        self.versions = self.parse_versions()
        self.boards = {}
        for version in self.versions:
            self.boards[version] = self.parse_boards(version)

    def parse_versions(self):
        p = self.path + "skels/versions.xml"
        check_path(p)
        r = ET.parse(p)
        versions = []
        for e in r.findall("./release/[@version]"):
            versions.append(e.get("version"))
        return versions

    def get_versions(self):
        return self.versions
    
    def is_version(self, version):
        return version in self.versions

    def is_board(self, version, board):
        return self.is_version(version) and board in self.boards[version]

    def check_version(self,version):
        if(not self.is_version(version)):
            sys.exit("ERROR: %s is not a valid version" % str(version))

    def check_board(self,version, board):
        self.check_version(version)
        if(not self.is_board(version,board)):
            sys.exit("ERROR: %s is not a valid board for version %s" % (str(board), str(version)))
            
    def get_boards(self, version):
        self.check_version(version)
        return self.boards[version]

    def get_board_path(self,version, board):
        self.check_board(version, board)
        p = self.path + "skels/versions.xml"
        check_path(p)
        r = ET.parse(p)
        e = r.find("./release/[@version='%s']" % str(version))
        
        p = os.path.expandvars(e.get("path")) + "/" + board +"/"
        return p
        
    def get_board_xml(self,version, board):
        self.check_version(version)
        self.check_board(version, board)
        p = self.get_board_path(version,board)
        check_path(p)
        p = p + board + ".xml"
        check_path(p)
        return p
    
    def get_board_path(self,version, board):
        self.check_version(version)
        p = self.path + "skels/versions.xml"
        check_path(p)
        r = ET.parse(p)
        e = r.find("./release/[@version='%s']" % str(version))
        
        p = os.path.expandvars(e.get("path")) + "/" + board +"/"
        return p

    def get_tcl_path(self,version):
        return self.path + "/tcl/" + str(version) + "/"
        return p

    def parse_boards(self, version):
        self.check_version(version)
        p = self.path + "skels/versions.xml"
        check_path(p)
        
        r = ET.parse(p)
        es = r.findall("./release/[@version='%s']" % str(version))
        e = es[0]
        if(len(es) > 1):
            sys.exit("ERROR: Multiple matches for version %s" % str(version))

        p = os.path.expandvars(e.get("path")) + "/boards.xml"
        check_path(p)
        r = ET.parse(p)
        boards = []
        for e in r.iterfind(("./board/[@version='%s']" % version)):
            boards.append(e.get("name"))
        
        return boards


def contains_duplicates(l):
    len(l) != len(set(l))

def is_in_range(v, min, max):
    return (min <= v <= max)

def is_pow_2(v):
    """Return true if v is a power of two"""
    return v != 0 and ((v & (v - 1)) == 0)

def is_alphachar(s):
    return is_string(s) and s.isalpha() and len(s) == 1

def is_string(s):
    return isinstance(s, basestring)


def is_list(l):
    return isinstance(l, list)

def is_dict(l):
    return isinstance(l, dict)

def is_int(l):
    return isinstance(l, int)

def is_valid_verilog_name(s):
    if(not is_string(s)
       or s is ""
       or s[0].isdigit()
       or re.match(r'\w+',s) is None):
        return False
    return True

def key_error(ks, ds):
    print "In key-value map:"
    print ds
    sys.exit("Error! Key \"%s\" missing" % ks)
                     
def key_error_xml(ks, es):
    print "In Element:"
    print es
    sys.exit("Error! Key \"%s\" missing" % ks)

def value_error(ks, vs, vvs):
    sys.exit(("Error! Key \"%s\" has invalid value \"%s\". " +
              "Valid values are: %s")
              % (ks, vs , vvs))

def value_error_xml(ks, vs, vvs, es):
    print "In XML Element:"
    print es
    value_error(ks,vs,vvs)

def value_error_map(ks, vs, vvs, ds):
    print "In key-value map:"
    print ds
    value_error(ks,vs,vvs)
    
def tostr_dict(d):
    return json.dumps(d,indent=2)
    
def print_description(d):
    print tostr_dict(d)
    
