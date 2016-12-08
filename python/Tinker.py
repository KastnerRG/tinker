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
from IP import parse_string

class Tinker():
    __C_TCLXML_ENV_VAR_NAME = "TCLXML_PATH"
    __C_TINKER_PATH_ENV_VAR_NAME = "TINKER_PATH"
    __C_TINKER_SKELS_FOLDER = "skels"
    __C_TINKER_KNOWN_VERSIONS = set(["14.0", "15.1", "16.0"])
    
    def __init__(self, version=None, board=None, output=None):
        self.__check_env()

        tp = self.__get_tinker_path()
        self.__tinker_path = tp
        
        d = self.__parse()
        self.__check(d)

        self.__d = d

        if(version != None):
            self.check_version(version)
            self.__v = version
            
        if(board != None):
            if(version == None):
                sys.exit("Error!")
            else:
                self.check_version_board(version, board)
                self.__b = board
                
        if(output == None):
            output = "./"
        output = os.path.abspath(output)
        check_path(output)
        self.__output_path = output
        self.get_path_skel()

    def get_name(self, b, d):
        return b["name"] + "_" + d["name"]
    
    def get_path_skel(self):
        self.__check_init()
        p = self.__d[self.__v][self.__b]["path"]
        check_path(p)
        return p
        
    def get_path_skel_xml(self):
        p = self.get_path_skel()
        f = self.get_name_skel_xml()
        return p +"/" + f
    
    def get_name_skel_xml(self):
        f = self.__d[self.__v][self.__b]["xml"]
        return f
    
    def get_path_output(self, b, d):
        return self.__output_path + "/" + self.get_name(b, d)

    def get_path_tcl(self):
        self.__check_init_version()
        self.check_version(self.__v)
        return self.__tinker_path + "/tcl/" + str(self.__v) + "/"
    
    def get_version(self):
        self.__check_init_version()
        return self.__v
    
    def get_board(self):
        self.__check_init_board()
        return self.__b
    
    def get_versions(self):
        for v in self.__d.keys():
            self.check_version(version)
        return self.__d.keys()
        
    def get_boards_version(self, version):
        self.check_version(version)
        return self.__d[version]["boards"]

    def __get_tinker_path(self):
        p = os.path.expandvars("${TINKER_PATH}") + "/"
        return p
    
    def __get_tclxml_path(self):
        p = os.path.expandvars("${TCLXML_PATH}") + "/"
        return p
            
    def check_version(self, version):
        if(str(version) not in self.__C_TINKER_KNOWN_VERSIONS):
            sys.exit(("Error! \"%s\" is not a known Quartus version. "
                     + "Valid versions are: %s")
                     % (str(version),
                        str(list(self.__C_TINKER_KNOWN_VERSIONS))))
        if(not self.__is_version(version)):
            sys.exit("ERROR: %s is not a valid version" % str(version))

    def check_version_board(self, version, board):
        self.check_version(version)
        if(not self.__is_board(version,board)):
            sys.exit("ERROR: %s is not a known board for version %s"
                     % (str(board), str(version)))
            
    def __check(self, d):
        for (v,dv) in d.iteritems():
            pv = dv["path"]
            check_path(pv)
            for b in dv["boards"]:
                pb = dv[b]["path"]
                check_path(pb)
                
    def __check_init_version(self):
        if(self.__v is None):
            sys.exit("Error! Tinker object not initialized"
                     + " with a Quartus version")
            
    def __check_init_board(self):
        if(self.__b is None):
            sys.exit("Error! Tinker object not initialized"
                     + " with a Board name")
    def __check_init(self):
        self.__check_init_version()
        self.__check_init_board()
        
    def __check_env(self):
        check_env_var(self.__C_TCLXML_ENV_VAR_NAME)
        check_path(self.__get_tclxml_path())
        check_abs(self.__get_tclxml_path())
        check_env_var(self.__C_TINKER_PATH_ENV_VAR_NAME)
        check_path(self.__get_tinker_path())
        check_abs(self.__get_tinker_path())
        
    def __parse(self):
        vs = self.__parse_versions(self.__tinker_path)
        vdb = {}
        for v in vs:
            dv = {}
            dv["path"] = self.__parse_path_version_dir(v)
            dv["boards"] = self.__parse_boards(v)
            for b in dv["boards"]:
                dv[b] = {"path":self.__parse_path_board_dir(v, b),
                         "xml":self.__parse_name_board_xml(v, b)}
            vdb[v] = dv
        return vdb
    
    def __parse_path_version_dir(self, v):
        p = self.__parse_path_version_xml()
        
        r = ET.parse(p)
        e = r.find("./release/[@version='%s']" % str(v))
        p = os.path.expandvars(parse_string(e,"path"))
        check_path(p)
        return p
        
    def __parse_path_version_xml(self):
        p = self.__tinker_path + self.__C_TINKER_SKELS_FOLDER + "/versions.xml"
        check_path(p)
        return p
        
    def __parse_versions(self, tp):
        p = self.__parse_path_version_xml()
        
        r = ET.parse(p)
        vs = [parse_string(e,"version") for e in r.findall("./release/[@version]")]
        return vs

    def __parse_path_board_dir(self, version, board):
        pv = self.__parse_path_version_dir(version)
        check_path(pv)
        pvx = pv + "/boards.xml"
        check_path(pvx)
        
        r = ET.parse(pvx)
        e = r.find("./board/[@name='%s']" % board)

        pd = pv + "/" + os.path.expandvars(parse_string(e,"path"))
        check_path(pd)
        
        return pd
    
    def __parse_name_board_xml(self, version, board):
        pv = self.__parse_path_version_dir(version)
        check_path(pv)
        pvx = pv + "/boards.xml"
        check_path(pvx)
        
        r = ET.parse(pvx)
        e = r.find("./board/[@name='%s']" % board)

        f = parse_string(e,"xml")
        return f

    def __parse_boards(self, version):
        p = self.__tinker_path + "skels/versions.xml"
        check_path(p)
        
        r = ET.parse(p)
        es = r.findall("./release/[@version='%s']" % str(version))
        e = es[0]
        if(len(es) > 1):
            sys.exit("ERROR: Multiple matches for version %s" % str(version))

        p = os.path.expandvars(parse_string(e,"path")) + "/boards.xml"
        check_path(p)
        r = ET.parse(p)
        boards = []
        for e in r.iterfind(("./board/[@version='%s']" % version)):
            boards.append(parse_string(e,"name"))
        
        return boards
    
    def __is_version(self, v):
        return v in self.__d.keys()

    def __is_board(self, v, b):
        return self.__is_version(v) and b in self.__d[v]["boards"]

def contains_duplicates(l):
    len(l) != len(set(l))

def is_in_range(v, min, max):
    return (min <= v <= max)

def is_pow_2(v):
    return v != 0 and ((v & (v - 1)) == 0)

def is_alphabetic(s):
    return is_string(s) and s.isalpha() and len(s) == 1

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

def is_float(l):
    return isinstance(l, float)

def is_id(i):
    return is_string(i) and i.isalpha()

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

def path_error_xml(t, es):
    print "In XML Element:"
    print es
    sys.exit("Subelement with path %s not found" % t)
    
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
        
def prettify(elem):
    rough_string = ET.tostring(elem, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")

def clog2(i):
    return math.floor(math.log(i)/math.log(2))

def check_path(p):
    if(not os.path.exists(p)):
        sys.exit("ERROR: Path %s does not exist" % p)
        
def check_abs(p):
    if(not os.path.isabs(p)):
        sys.exit("Error! Path %s is not an absolute path" % p)
        
def check_env_var(v):
    if(v not in os.environ):
        sys.exit("Error! Environment Variable %s not set" % v)
