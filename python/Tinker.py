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
import xml.etree.ElementTree as et, math, os
from xml.dom import minidom

def is_number(n):
    try:
        float(n)
        return True
    except ValueError:
        return False            

def is_alphachar(s):
    return s.isalpha() and len(s) == 1

def match_enum(id, enum):
    return ((is_alphachar(id) and enum == "alphabetical") or
        (is_number(id) and enum == "numerical"))

def list_diff(l,cl):
    return list(set(l) - set(cl))

def prettify(elem):
    rough_string = et.tostring(elem, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")

def clog2(i):
    return math.floor(math.log(i)/math.log(2))

def rate2int(ratio):
    if(ratio == "single"):
        return 1
    elif(ratio == "double"):
        return 2

def ratio2float(ratio):
    if(ratio =="Full"):
        return 1
    if(ratio =="Half"):
        return .5
    if(ratio =="Quarter"):
        return .25

def checkvar(v):
    if(v not in os.environ):
        print "ERROR: Environment Variable %s not set",v
        exit(1)

def checkenv():
    checkvar("TCLXML_PATH")
    checkvar("TINKER_PATH")

def check_path(p):
    if(not os.path.exists(p)):
        print "ERROR: Path %s does not exist", p
        exit(1)

class Tinker():
    def __init__(self):
        checkenv()
        self.path = os.path.expandvars("${TINKER_PATH}") + "/"
        check_path(self.path)
        self.versions = self.parse_versions()
        self.boards = {}
        for version in self.versions:
            self.boards[version] = self.parse_boards(version)

    def parse_versions(self):
        p = self.path + "boards/versions.xml"
        check_path(p)
        r = et.parse(p)
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
            print "ERROR: %s is not a valid version" % str(version)
            exit(1)

    def check_board(self,version, board):
        self.check_version(version)
        if(not self.is_board(version,board)):
            print "ERROR: %s is not a valid board for version %s" % (str(board), str(version))
            exit(1)
            
    def get_boards(self, version):
        self.check_version(version)
        return self.boards[version]

    def get_board_path(self,version, board):
        self.check_board(version, board)
        p = self.path + "boards/versions.xml"
        check_path(p)
        r = et.parse(p)
        e = r.find("./release/[@version='%s']" % str(version))
        
        p = os.path.expandvars(e.get("path")) + "/" + board +"/"
        return p
        
    def get_board_xml(self,version, board):
        return self.get_board_path(version,board) +board + ".xml"
    
    def get_board_path(self,version, board):
        self.check_version(version)
        p = self.path + "boards/versions.xml"
        check_path(p)
        r = et.parse(p)
        e = r.find("./release/[@version='%s']" % str(version))
        
        p = os.path.expandvars(e.get("path")) + "/" + board +"/"
        return p

    def get_tcl_path(self,version):
        return self.path + "/tcl"
        return p

    def parse_boards(self, version):
        self.check_version(version)
        p = self.path + "boards/versions.xml"
        check_path(p)
        
        r = et.parse(p)
        es = r.findall("./release/[@version='%s']" % str(version))
        e = es[0]
        if(len(es) > 1):
            print "ERROR: Multiple matches for version %s" % str(version)

        p = os.path.expandvars(e.get("path")) + "/boards.xml"
        check_path(p)
        r = et.parse(p)
        boards = []
        for e in r.iterfind(("./board/[@version='%s']" % version)):
            boards.append(e.get("name"))
        
        return boards

