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
# Filename: Phy.py
# Version: 0.1 
# Description: Defines the methods available to a single physical interface (PHY),
# more specifically a type of memory (i.e. DDR, QDR, etc)
# Author: Dustin Richmond

# Import Python Utilities
import xml.etree.ElementTree as ET
from collections import defaultdict
# Import Tinker Objects
import Tinker, IP

class Phy(IP.IP):
    def __init__(self, e, t, enum):
        super(Phy,self).__init__(e)
        self.t = t;
        info = self.__parse_info(e,t,enum) 
        self.info.update(info)
        self.params = self.__parse_params(e)

    def __parse_info(self, e, t, enum):
        d = defaultdict()
        id = e.get("id")
        d["id"] = id
        if(not Tinker.is_alphachar(id)):
            print (("ERROR: Expected alphabetical character ID for type %s but ID is %s.\n" +
                        "Check the board-specific XML file") %
                        (t, id))
            exit(1)

        macro = e.get("macro")
        d["macro"] = macro

        roles = [s.strip() for s in e.get("roles").split(",")]
        err = Tinker.list_diff(roles,["primary","secondary","independent"])
        if(len(err) > 0):
            print "ERROR: Unrecognized role(s) in XML file: %s" % str(err)
            exit(1)

        d["roles"] = roles

        gs = [s.strip() for s in e.get("grouping").split(",")]
        gs.remove(id)
        for p in gs:
            if(not Tinker.is_alphachar(p)):
                print (("ERROR: Expected alphabetical character ID for type %s but ID is %s.\n" +
                        "Check the board-specific XML file") %
                        (t, id))
                exit(1)
        d["group"] = gs
        
        ports = [s.strip() for s in e.get("ports").split(",")]
        err = Tinker.list_diff(ports,["r","w","rw"])
        if(len(err) > 0):
            print (("ERROR: Unknown port type(s) for %s, id %s in XML file: %s" +
                    "Check the board-specific XML file") %
                    (t, id,str(err)))
            exit(1)
        d["ports"] = ports

        ratios = [s.strip() for s in e.get("ratios").split(",")]
        err = Tinker.list_diff(ratios,["Quarter","Half","Full"])
        if(len(err) > 0):
            print (("ERROR: Unknown ratio type(s) for %s, id %s in XML file: %s\n" +
                    "Check the board-specific XML file") %
                    (t, id,str(err)))
            exit(1)
        d["ratios"] = ratios

        rate = e.get("rate")
        err = Tinker.list_diff([rate],["single","double"])
        if(len(err) > 0):
            print (("ERROR: Unknown rate for %s, id %s in XML file: %s\n" +
                    "Check the board-specific XML file") %
                    (t, id,str(err)))
            exit(1)
        d["rate"] = rate

        fref_mhz = e.get("fref_mhz")
        if(not Tinker.is_number(fref_mhz)):
            print (("ERROR: Maximum Frequency of type %s, is %s was %s, which is not a number.\n" +
                        "Check the board-specific XML file") %
                        (t, id, str(fref)))
            exit(1)
        d["fref_mhz"] = int(fref_mhz)
        return d

    def __parse_params(self,e):
        ps = {}
        for p in e.findall("./parameter"):
            ps[p.get("name")] = p.get("value")
        return ps

    def get_info(self):
        return self.info

    def print_info(self,l):
        print l*"\t" + "Interface ID: %s" % self.info["id"]
        print (l + 1)*"\t" + "Size: 0x%x (%d bytes)" % (self.info["size"],self.info["size"])
        print (l + 1)*"\t" + "Max Freq: %s MHz" % str(self.info["fmax_mhz"])
        print (l + 1)*"\t" + "Fabric Ratios: %s" % str(self.info["ratios"])
        print (l + 1)*"\t" + "Associated Interfaces: %s" % str(self.info["group"])
        print (l + 1)*"\t" + "Roles: %s " % str(self.info["roles"])
        print (l + 1)*"\t" + "Ports: %s " % str(self.info["ports"])

    def set_params(self):
        pass

    def build_spec(self, spec, n , id, base, burst, width, specification=False):
        s = spec.get_info()
        size = int(s[n][id]["Size"],16)
        if(size > self.info["size"]):
            print "ERROR! Size is too large for memory"
            exit(1)
        r = ET.Element("interface", attrib={"name": "tinker", "type":"slave", "address":str(hex(base)), "size":str(hex(size))})

        # Check that the width is valid:
        dqp2 = self.info["pow2_dq_pins"]
        ratio_ok = False;
        rate = Tinker.rate2int(self.info["rate"])
        ratio = "notok"
        for v in self.info["ratios"]:
            if(width == int(rate * dqp2 / Tinker.ratio2float(v))):
                ratio = Tinker.ratio2float(v)
                ratio_ok = True
                break
        if(ratio is "not ok"):
                print "ERROR: No possible fabric ratio for desired fabric width in System %s" % id
                exit(1)
        r.set("width", str(width))
        r.set("maxburst", str(burst))
        if(specification):
            primary = s[n]["Primary"]
            r.set("id", str(id))
            r.set("ratio", v)
            r.set("role", s[n][id]["Role"])
            if(s[n][id]["Role"] == "secondary"):
                r.set("shared","pll,dll,oct")
                r.set("primary",primary)
            elif(s[n][id]["Role"] == "independent"):
                r.set("shared","oct")
                r.set("primary",primary)
            else:
                r.set("shared","")

            r.set("mem_frequency_mhz",str(self.info["fmax_mhz"]))
            r.set("ref_frequency_mhz",str(self.info["fref_mhz"]))
            
        return r

    def gen_macros(self, spec, n):
        return "`define " + self.info["macro"] + "\n"
        
def initialize(t, e, enum):
    if(t == "DDR3"):
       import DDR
       return DDR.DDR(e, enum)
    elif(t == "QDRII"):
       import QDR
       return QDR.QDR(e, enum)
    elif(t == "LOCAL"):
       import LOCAL
       return LOCAL.LOCAL(e, enum)
                                           
