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

# Import Python Utilities
import xml.etree.ElementTree as ET, math
from collections import defaultdict
# Import Tinker Objects
import DDR, QDR, Phy, IP, Tinker

class Memory(IP.IP):
    def __init__(self, xml):
        super(Memory, self).__init__(xml)
        self.ifs = {}
        info = self.parse_info(xml) 
        self.info.update(info)
        self.spec_keys = {"name": max}
        self.specification_keys = {}
        
    def get_info(self):
        return self.info;

    def print_info(self,l):
        print "Showing info for memory type %s:" % self.info["type"]
        if(self.info["division"] != "continuous"):
            print l*"\t" + "Number of Interfaces: %d" % int(self.info["quantity"])
        for k,i in self.ifs.iteritems():
            i.print_info(l)

    def parse_info(self,r):
        d = defaultdict();
        t = r.get("type")
        d["type"] = t
        d["enumeration"] = r.get("enum")
        d["division"] = r.get("division")
        d["burst"] = r.get("burst") # TODO
        # TODO: List diff for enum
        if(d["division"] == "discrete"):
            d["quantity"] = r.get("quantity")
        else:
            d["quantity"] = "\"infinite\""
        d["ids"] = []
        for e in r.findall("./[@type='%s']/*" % t):
            mem = Phy.initialize(t, e, d["enumeration"])
            di = mem.get_info()
            d[di["id"]] = di
            d["ids"].append(di["id"])
            self.ifs[di["id"]] = mem
        return d

    def build_spec(self,spec, n, base, specification=False):
        s = spec.get_info()
        r = ET.Element("global_mem", attrib={"name": self.info["type"] + "_" + str(n)})
        burst = s.get("Burst","16")
        
        if0 = s[n]["Interfaces"][0]
        width = int(1/(Tinker.ratio2float(s[n]["Ratio"])) * self.info[if0]["pow2_dq_pins"] * self.info[if0]["clock_ratio"])
        intbytes = int(burst) * width / 8
        r.set("interleaved_bytes", str(intbytes))
        if(n == "0"):
            r.set("config_addr", "0x018")
            if(len(s["Systems"]) > 1 or  specification):
                r.set("default","1")
        else:
            r.set("config_addr", hex(int("0x100",16) + (int(n)-1) * int("0x18",16)))

        size = 0
        bandwidth = 0
        for id in s[n]["Interfaces"]:
            bandwidth += self.info[id]["bandwidth_bs"]
            i = self.ifs[id]
            e = i.build_spec(spec,n,id,base+size,burst,width,specification=specification)
            size += int(s[n][id]["Size"],16)
            r.append(e);
        
        r.set("max_bandwidth", str(int(bandwidth)/1000000))
        if(specification):
            r.set("base_address",hex(base))
            r.set("quantity",str(len(s[n]["Interfaces"])))
            r.set("width",str(width))
            r.set("sys_id",str(n))
            r.set("type",s[n]["Type"])
            r.set("maxburst",str(burst))
            r.set("addr_width",str(int(math.log(size,2))))
            r.set("role",s[n]["Role"])
        return r

    def gen_macros(self, spec, n):
        s = spec.get_info()
        macros =""
        for intf in s[n]["Interfaces"]:
            i = self.ifs[intf]
            macros += i.gen_macros(spec, n)
        return macros

