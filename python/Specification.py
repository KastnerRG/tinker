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
# Filename: Specification.py
# Version: 0.1 
# Description: An object encapsulating the specification files
# board_spec.xml and board_specification.xml. 
# Author: Dustin Richmond

# Import Python Utilities
import json, xml.etree.ElementTree as ET
from collections import defaultdict
# Import Tinker Objects
import IP, Board, Description

class Specification(defaultdict):
    def __init__(self, d, b):
        """Construct a Specification Object

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        b -- A Board object, containing the parsed description of a board and
        its associated interfaces and custom IP
        
        """
        self.validate(d,b)
        self.update(self.build(d,b))

    @classmethod
    def validate(cls, d, b):
        """Validate a description and verify that it can be applied to
        a board.

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        b -- A Board object, containing the parsed description of a board and
        its associated interfaces and custom IP
        
        """
        pass

    @classmethod    
    def build(cls, d, b):
        """Build a dictionary implementing the custom board described in the
        user description as applied to the specified board

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        b -- A Board object, containing the parsed description of a board and
        its associated interfaces and custom IP
        
        """
        self.validate(d,b)
        pass
"""
    def generate(self):
        s = spec.get_info()
        
        if(version == "14.1" and not specification):
            r = ET.Element("board", attrib={"version": "0.9", "name":self.info["name"] + "_" + s["Name"]})
        else:
            r = ET.Element("board", attrib={"version": version, "name":self.info["name"] + "_" + s["Name"]})
        if(specification):
            r.set("file", self.info["name"]+".xml")

        # Compile Directives
        #  <compile project="top" revision="top" qsys_file="system.qsys" generic_kernel="1">
        #    <generate cmd="qsys-generate --synthesis=VERILOG system.qsys"/>
        #    <synthesize cmd="quartus_sh --flow compile top -c top"/>
        #    <auto_migrate platform_type="auto" >
        #      <include fixes=""/>
        #      <exclude fixes=""/>
        #    </auto_migrate>
        #  </compile>
        c = ET.SubElement(r,"compile", attrib={"project":"top",
                                           "revision":"top",
                                           "qsys_file":"system.qsys",
                                           "generic_kernel":"1"})
        ET.SubElement(c,"generate", attrib={"cmd":"qsys-generate --synthesis=VERILOG system.qsys"})
        ET.SubElement(c,"synthesize", attrib={"cmd":"quartus_sh --flow compile top -c top"})
        am = ET.SubElement(c,"auto_migrate", attrib={"platform_type":"auto"})
        ET.SubElement(am,"include", attrib={"fixes":""})
        ET.SubElement(am,"exclude", attrib={"fixes":""})
                                                  
        # Summary of Resources
        resources = Counter({"alms":0,
                             "ffs":0,
                             "rams":0,
                             "dsps":0})
        
        for sys in s["Systems"]:
            t = s[sys]["Type"]
            resources.update(self.info[t]["resources"])

            for i in s[sys]["Interfaces"]:
                resources.update(self.info[t][i]["resources"])
        deve = ET.SubElement(r,"device", attrib={"device_model":self.info["model"]})
        re = ET.SubElement(deve,"used_resources")
        for rt,num in resources.iteritems():
            ET.SubElement(re, rt, attrib={"num":str(num)})

        base = 0
        size_default = 0
        for sys in s["Systems"]:
            # TODO: Set default burst and document
            # This is pretty ugly. We should check and set defaults when we first parse the specification.
            if("Burst" not in s[sys]):
                s[sys]["Burst"] = 16
            t = s[sys]["Type"]
            m = self.types[t]
            sz = 0
            for i in s[sys]["Interfaces"]:
                sz += int(s[sys][i]["Size"],16)

            # Update Base. Base address must be size-aligned.
            if((base % sz) is not 0):
                base += (sz - (base % sz))

            # Round the base address to the nearest multiple of the interface size.
            e = m.build_spec(spec,sys,base,specification=specification)
            r.append(e)

            base += sz
            if(sys == "0"):
                 # TODO: God this is ugly. But it's seemingly the only way to calculate the width cleanly (unless we do it in the specification step)
                log_sz = int(math.log(sz)/math.log(2))
                b = int(s["0"]["Burst"])
                burstw = int(math.log(b)/math.log(2)) + 1
                m_if0 = s["0"]["Interfaces"][0]

                m_info = m.get_info()
                m_width = int(1/(Tinker.ratio2float(s["0"]["Ratio"])) * m_info[m_if0]["dq_pins"] * m_info[m_if0]["clock_ratio"])
                m_bytes = m_width/8
                log_b = int(math.log(m_bytes)/math.log(2))

                #print log_sz, b, burstw

        # ACL Plumbing
        intfs = ET.SubElement(r, "interfaces")
        
        # TODO: What is the purpose of misc?
        kernel_cra = ET.SubElement(intfs,"interface",
                                   attrib={"name":"tinker",
                                            "port":"kernel_cra",
                                            "type":"master",
                                            "width":"64",
                                            "misc":"0"})

        kernel_irq = ET.SubElement(intfs,"interface",
                                   attrib={"name":"tinker",
                                           "port":"kernel_irq",
                                           "type":"irq",
                                           "width":"1"})
        snoop = ET.SubElement(intfs,"interface",
                              attrib={"name":"tinker",
                                      "port":"acl_internal_snoop",
                                      "type":"streamsource",
                                      "enable":"SNOOPENABLE",
                                      "clock":"tinker.kernel_clk",
                                      "width":str(log_sz - log_b  + burstw + 1)})
        kclk_rst = ET.SubElement(intfs,"kernel_clk_reset",
                                 attrib={"clk":"tinker.kernel_clk",
                                         "clk2x":"tinker.kernel_clk2x",
                                         "reset":"tinker.kernel_reset"})
        # Host Interface
        host = ET.SubElement(r,"host")
        ET.SubElement(host,"kernel_config",
                      attrib={"start":"0x00000000","size":"0x0100000"})        
        return r

    def gen_macros(self, spec):
        s = spec.get_info()
        macros =""
        for sys in s["Systems"]:
            t = s[sys]["Type"]
            mem = self.types[t]
            macros += mem.gen_macros(spec, sys)
        return macros

    def gen_system(self, spec, sysxml):
        sysroot = ET.parse(sysxml).getroot()
        s = spec.get_info()
        for sys in s["Systems"]:
            t = s[sys]["Type"]
            for i in s[sys]["Interfaces"]:
                n = t.lower()+ "_" + i
                r = s[sys][i]["Role"]
                ET.SubElement(sysroot,"interface",
                              attrib={"name":n,
                                      "internal":"tinker."+n,
                                      "type":"conduit",
                                      "dir":"end"})
                if(r == "primary"):
                    ET.SubElement(sysroot,"interface",
                                  attrib={"name":n+"_mem_oct",
                                          "internal":"tinker."+n+"_oct",
                                          "type":"conduit",
                                          "dir":"end"})
                if(r == "primary" or r == "independent"):
                    ET.SubElement(sysroot,"interface",
                                  attrib={"name":n + "_pll_ref",
                                          "internal":"tinker."+n+"_pll_ref",
                                          "type":"conduit",
                                          "dir":"end"})
        return sysroot
"""
