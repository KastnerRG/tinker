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

import xml.etree.ElementTree as ET, sys
import Tinker, MemoryType
from IP import parse_float, parse_int, parse_string, parse_list, findsingle

class Board(dict):
    def __init__(self, tinker):
        self.__t = tinker
        et = ET.parse(self.__t.get_path_skel_xml())
        d = self.__parse(et)
        self.__verify(d) 
        self.update(d)
        
    def __verify(self,d):
        # TODO: 
        pass
    
    def __str__(self):
        return json.dumps(self, indent=2)
                    
    def __parse(self, et):
        r = et.getroot()
        d = self.__parse_board_elem(r)
        e = findsingle(r, "IP")
        d["IP"] = self.__parse_ip(e)

        e = findsingle(r, "compile")
        d["compile"] = self.__parse_compile(e)
        
        d.update()
        return d

    def __parse_board_elem(self, e):
        d = dict()
        d["version"] = parse_float(e,"version")
        d["name"] = parse_string(e,"name")
        d["model"] = parse_string(e,"model")
        return d
        
    def __parse_compile(self, e):
        d = dict()
        d["qsys_file"] = parse_string(e, "qsys_file")
        d["project"] = parse_string(e, "project")
        d["revision"] = parse_string(e, "revision")
        d["auto_migrate"] = self.__parse_automigrate(e)
        return d
        
    def __parse_automigrate(self, e):
        ea = findsingle(e, "auto_migrate")
        d = dict()
        d["platform_type"] = parse_string(ea, "platform_type")
        ei = findsingle(ea, "include")
        d["include"] = parse_string(ei, "fixes")
        ee = findsingle(ea, "exclude")
        d["exclude"] = parse_string(ee, "fixes")
        return d
    
    def __parse_ip(self, e):
        d = dict()
        d["types"] = parse_list(e, "types")
        for t in d["types"]:
            se = findsingle(e, t)
            if(t == "memory"):
                d[t] = MemoryType.MemoryType(se)
        return d
            
    def get_compile_element(self):
        e = ET.Element("compile",
                       attrib={"project":self["compile"]["project"],
                               "revision":self["compile"]["revision"],
                               "qsys_file":self["compile"]["qsys_file"],
                               "generic_kernel":"1"})
        gena = {"cmd":"qsys-generate --synthesis=VERILOG %s"
                % self["compile"]["qsys_file"]}
        ET.SubElement(e,"generate", attrib=gena)
        syna= {"cmd":"quartus_sh --flow compile %s -c %s" %
               (self["compile"]["project"], self["compile"]["revision"])}
        ET.SubElement(e,"synthesis", attrib=syna)
        am = ET.SubElement(e,"auto_migrate",
                           attrib={"platform_type":
                                   self["compile"]["auto_migrate"]["platform_type"]})
        ET.SubElement(am,"include",
                      attrib={"fixes":
                              self["compile"]["auto_migrate"]["include"]})
        ET.SubElement(am,"exclude",
                      attrib={"fixes":
                              self["compile"]["auto_migrate"]["exclude"]})
        
        return e
