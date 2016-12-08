
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
# TODOs:
#       - OCT Pins - A Phy's OCT pin is in the board file, and should be used by the TCL Scripts
#                  - Naming
#                  - One oct per memory system (I think)
#                  - Macros to enable OCT pins (Sometimes OCT pins can be used by multiple IPs)
#       - QSys/TCL - Naming changed because types are now upper case

import xml.etree.ElementTree as ET
import Tinker, Memory
import abc, sys
from IP import parse_list, parse_string, parse_int, parse_id, parse_float, parse_macros, IP
class Phy(Memory.Memory):
    _C_BURST_WIDTHS = []
    _C_BURST_DEFAULT = 0
    _C_MAX_DATA_BUS_WIDTH = 2048
    _C_FPHY_MHZ_RANGE = (1,2000)
    _C_FPGA_MHZ_RANGE = (1,300)
    _C_FREF_MHZ_RANGE = (1,500)
    _C_DQ_PIN_RANGE = (0,128)
    _C_POW2_DQ_PIN_RANGE = (0,128)
    _C_BANDWIDTH_BS_RANGE= (0,1<<36)
    _C_SIZE_RANGE = (0,1<<32)
    
    def __init__(self, e):
        super(Phy,self).__init__(e)

    @classmethod
    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this IP

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        super(Phy, cls).validate(d)
        cls.check_size(d)
        cls.check_fphy_frequency(d)
        cls.check_fref_frequency(d)
        cls.check_dq_pins(d)
        cls.check_pow_2_dq_pins(d)
        cls.check_bandwidth_bs(d)

        return
        
    @classmethod
    def parse(cls,e):
        d = super(Phy, cls).parse(e)

        i = parse_id(e)
        fref_mhz = parse_float(e, "fref_mhz")
        fphy_mhz = parse_float(e, "fphy_mhz")
        dq_pins = parse_int(e, "dq_pins")
        macros = parse_macros(e)

        d["id"] = i
        d["fphy_mhz"] = fphy_mhz
        d["fref_mhz"] = fref_mhz
        d["dq_pins"] = dq_pins
        d["macros"] = macros
        
        group = cls.parse_grouping(e)
        group.remove(i)
        octs = cls.parse_oct_pins(e)

        d["group"] = group
        d["oct_pins"] = octs

        pow2_dq_pins = int(2 ** Tinker.clog2(dq_pins))
        d["pow2_dq_pins"] = pow2_dq_pins
        d["bandwidth_bs"] = int((d["fphy_mhz"] * 10**6 * cls._C_RATE * pow2_dq_pins) / 8)

        return d

        
    def configure(self, d):
        """

        Configure this object according to a high level description
        fill in any missing defaults, and verify that the description
        can be implemented

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        super(Phy,self).configure(d)
        if("ratio" not in d and "width" not in d):
            self["ratio"] = self.get_default_ratio()
            self["width"] = int(self["pow2_dq_pins"] * ratio2int(self["ratio"])) * self._C_RATE
            
        elif("ratio" not in d and "width" in d):
            self["ratio"] = int2ratio(d["width"]/ self["pow2_dq_pins"])

        elif("ratio" in d and "width" not in d):
            self["width"] = int(self["pow2_dq_pins"] & ratio2int(d["ratio"])) * self._C_RATE
            
        else:
            self["width"] = d["width"]
            self["ratio"] = d["ratio"]

        self["fpga_mhz"] = self["fphy_mhz"] / float(ratio2int(self["ratio"]))
            
        if("burst" not in d):
            self["burst"] = self.get_default_burst()
        else:
            self["burst"] = d["burst"]
            
        if("role" not in d):
            Tinker.key_error("role", Tinker.tostr_dict(d))
        else:
            self["role"] = d["role"]
            if(d["role"] != "primary"):
                if("master" not in d):
                    Tinker.key_error("master", Tinker.tostr_dict(d))
                else:
                    self["master"] = d["master"]

    def verify(self):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        super(Phy,self).verify()
        self.check_base_address(self);
        #self.check_oct_pin(self) # TODO: 
        self.check_role(self)

        self.check_ratio(self)
        self.check_width(self);
        self.check_burst(self)
        self.check_fphy_frequency(self)
        self.check_fref_frequency(self)
        self.check_fpga_frequency(self)
        if(self["role"] != "primary"):
            self.check_master(self)

    def __get_name(self):
        return self["type"] + "_" + self["id"]
    
    def __get_phy_interface(self, sid, version, verbose):
        # TODO: Change naming in TCL files
        n = self.__get_name()
        e = ET.Element("interface",attrib={"name":n, "internal":"tinker." + n,
                                           "type":"conduit", "dir":"end"})
        return e
    
    def __get_pll_interface(self, sid, version, verbose):
        n = self.__get_name()
        e = ET.Element("interface",attrib={"name":n + "_mem_pll_ref",
                                           "internal":"tinker." + n + "_pll_ref",
                                           "type":"conduit", "dir":"end"})
        return e
    
    def __get_oct_interface(self, sid, version, verbose):
        # TODO: Change naming in TCL files
        # TODO: OCT Pin macros
        n = self.__get_name()
        e = ET.Element("interface",attrib={"name":n + "_mem_oct", # TODO: Oct pin name
                                           "internal":"tinker." + n + "_oct",
                                           "type":"conduit", "dir":"end"})
        return e
        
    def get_pin_elements(self, sid, version, verbose):
        # TODO: Change naming in TCL files
        l = []
        l.append(self.__get_phy_interface(sid, version, verbose))
        r = self["role"]
        if(r =="primary" or r == "independent"):
            l.append(self.__get_pll_interface(sid, version, verbose))
        if(r =="primary"):
            l.append(self.__get_oct_interface(sid, version, verbose))
        return l

    def __get_interface_element(self, sid, version, verbose):
        e = ET.Element("interface")

        e.set("name","tinker")
        e.set("type","slave")
        e.set("address", str(hex(self["base_address"])))
        e.set("width", str(self["width"])) 
        e.set("maxburst", str(self["burst"]))
        e.set("latency", str(self["latency"]))
        return e
    
    def get_interface_element(self, sid, version, verbose):
        self.verify()
        e = self.__get_interface_element(sid, version, verbose)
        
        if(verbose):
            self.__set_verbose_interface_element(e)
            
        return e
    
    def __set_verbose_interface_element(self, e):
        e.set("id", self["id"])
        e.set("ratio", self["ratio"])
        e.set("role", self["role"])
        e.set("mem_frequency_mhz",str(int(self["fphy_mhz"])))
        e.set("ref_frequency_mhz",str(int(self["fref_mhz"])))
            
        if(self["role"] == "secondary"):
            e.set("shared","pll,dll,oct")
            e.set("primary",self["master"])
        elif(self["role"] == "independent"):
            #e.set("shared",self["oct_pin"])
            e.set("shared","oct")
            e.set("primary",self["master"])
        else:
            e.set("shared","")

    @classmethod
    def get_default_burst(cls):
        return cls._C_BURST_DEFAULT
    
    @classmethod
    def get_default_ratio(cls):
        if("Quarter" in cls._C_CLOCK_RATIOS):
            return "Quarter"
        if("Half" in cls._C_CLOCK_RATIOS):
            return "Half"
        return "Full"

    @classmethod
    def check_ratio(cls, d):
        ratio = d.get("ratio")
        if(ratio is None):
            Tinker.key_error("ratio", Tinker.tostr_dict(d))
        if(ratio not in cls._C_CLOCK_RATIOS):
            Tinker.value_error_xml("ratio", ratio, str(list(cls._C_CLOCK_RATIOS)),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_role(cls, d):
        role = d.get("role")
        roles = d.get("roles")
        if(role is None):
            Tinker.key_error("role", Tinker.tostr_dict(d))
        if(roles is None):
            Tinker.key_error("roles", Tinker.tostr_dict(d))
        if(role not in cls._C_ROLES):
            Tinker.value_error_xml("role", role, str(list(cls._C_ROLES)),
                                   Tinker.tostr_dict(d))
        if(role not in roles):
            Tinker.value_error_map("role", role, str(roles),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_oct_pin(cls, d):
        oct_pin = d.get("oct_pin")
        oct_pins = d.get("oct_pins")
        if(oct_pin is None):
            Tinker.key_error("oct_pin", Tinker.tostr_dict(d))
        if(oct_pin is None):
            Tinker.key_error("oct_pins", Tinker.tostr_dict(d))
        if(oct_pin not in self["oct_pins"]):
            Tinker.value_error_map("oct_pin", role, str(oct_pins),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_base_address(cls, d):
        cls.check_size(d)
        sz = d.get("size")
        base = d.get("base_address")
        if(base is None):
            Tinker.key_error("base_address", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(base, 0, (2 ** 64) - sz)):
            Tinker.value_error_map("base_address", str(base),
                                   "Range(0x%x, 0x%x)" % (0, (2**64) - sz),
                                   Tinker.tostr_dict(d))
        if((base % sz) != 0):
            Tinker.value_error_map("base_address", str(base),
                                   "Multiples of 0x%x (Size)" % sz,
                                   Tinker.tostr_dict(d))
    
    @classmethod
    def check_width(cls, d):
        cls.check_pow_2_dq_pins(d)
        cls.check_ratio(d)
        p2dqp = d["pow2_dq_pins"]
        r = d["ratio"]
        rw = int(p2dqp* cls._C_RATE * ratio2int(r))
        width = d.get("width")
        if(width is None):
            Tinker.key_error("width", Tinker.tostr_dict(d))
        if(not Tinker.is_pow_2(width)):
            Tinker.value_error_map("width", str(width),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))
        if(width % p2dqp != 0):
            Tinker.value_error_map("width", str(width),
                                   "Multiple of 0x%x (Pow2 DQ Width)" % p2dqp,
                                   Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(width, 0, cls._C_MAX_DATA_BUS_WIDTH)):
            Tinker.value_error_map("width", str(width),
                                   str(list(cls._C_MAX_DATA_BUS_WIDTH)),
                                   Tinker.tostr_dict(d))
        if(rw != width):
            Tinker.value_error_map("width", str(w), str(rw), Tinker.tostr_dict(d))

    @classmethod
    def check_burst(cls, d):
        burst = d.get("burst")
        if(burst is None):
            Tinker.key_error("burst", Tinker.tostr_dict(d))
        if(not Tinker.is_pow_2(burst)):
            Tinker.value_error_map("burst", str(burst),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))
        if(burst not in cls._C_BURST_WIDTHS):
            Tinker.value_error_map("burst", str(burst),
                                   str(list(cls._C_BURST_WIDTHS)),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_fpga_frequency(cls, d):
        fpga = d.get("fpga_mhz")
        fpga_min = cls._C_FPGA_MHZ_RANGE[0]
        fpga_max = cls._C_FPGA_MHZ_RANGE[1]
        if(fpga is None):
            Tinker.key_error("fpga_mhz", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(fpga, fpga_min, fpga_max)):
            Tinker.value_error_map("fpga_mhz", str(fpga),
                                   "Range(0x%x, 0x%x)" % (fpga_min, fpga_max),
                                   Tinker.tostr_dict(d))
    @classmethod
    def check_fphy_frequency(cls, d):
        fphy = d.get("fphy_mhz")
        fphy_min = cls._C_FPHY_MHZ_RANGE[0]
        fphy_max = cls._C_FPHY_MHZ_RANGE[1]
        if(fphy is None):
            Tinker.key_error("fphy_mhz", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(fphy, fphy_min, fphy_max)):
            Tinker.value_error_map("fphy_mhz", str(fphy),
                                   "Range(0x%x, 0x%x)" % (fphy_min, fphy_max),
                                   Tinker.tostr_dict(d))
    
    @classmethod
    def check_fref_frequency(cls, d):
        fref = d.get("fref_mhz")
        fref_min = cls._C_FREF_MHZ_RANGE[0]
        fref_max = cls._C_FREF_MHZ_RANGE[1]
        if(fref is None):
            Tinker.key_error("fref_mhz", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(fref, fref_min, fref_max)):
            Tinker.value_error_map("fref_mhz", str(fref),
                                   "Range(0x%x, 0x%x)" % (fref_min, fref_max),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_dq_pins(cls, d):
        p = d.get("dq_pins")
        dq_min = cls._C_DQ_PIN_RANGE[0]
        dq_max = cls._C_DQ_PIN_RANGE[1]
        if(p is None):
            Tinker.key_error("dq_pins", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(p, dq_min, dq_max)):
            Tinker.value_error_map("dq_pins", str(p),
                                   "Range(0x%x, 0x%x)" % (dq_min, dq_max),
                                   Tinker.tostr_dict(d))
    @classmethod
    def check_pow_2_dq_pins(cls, d):
        p = d.get("pow2_dq_pins")
        pdq_min = cls._C_POW2_DQ_PIN_RANGE[0]
        pdq_max = cls._C_POW2_DQ_PIN_RANGE[1]
        if(p is None):
            Tinker.key_error("pow2_dq_pins", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(p, pdq_min, pdq_max)):
            Tinker.value_error_map("pow2_dq_pins", str(p),
                                   "Range(0x%x, 0x%x)" % (pdq_min, pdq_max),
                                   Tinker.tostr_dict(d))
        if(not Tinker.is_pow_2(p)):
            Tinker.value_error_map("pow2_dq_pins", str(p),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_bandwidth_bs(cls, d):
        bw = d.get("bandwidth_bs")
        bw_min = cls._C_BANDWIDTH_BS_RANGE[0]
        bw_max = cls._C_BANDWIDTH_BS_RANGE[1]
        if(bw is None):
            Tinker.key_error("bandwidth_bs", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(bw,bw_min,bw_max)):
            Tinker.value_error_map("bandwidth_bs", str(hex(bw)),
                                   "Range(0x%x, 0x%x)" % (bw_min, bw_max),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_size(cls, d):
        sz = d.get("size")
        sz_min = cls._C_SIZE_RANGE[0]
        sz_max = cls._C_SIZE_RANGE[1]
        if(sz is None):
            Tinker.key_error("size", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(sz, sz_min, sz_max)):
            Tinker.value_error_map("size", str(hex(sz)),
                                   "Range(0x%x, 0x%x)" % (sz_min, sz_max),
                                    Tinker.tostr_dict(d))
        if(not Tinker.is_pow_2(sz)):
            Tinker.value_error_map("pow2_dq_pins", str(sz),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))
        
    @classmethod
    def check_master(cls, d):
        id = d.get("master")
        if(not id.isalpha()):
            Tinker.value_error_xml("master", id, "Alphabetic strings",
                                   ET.tostring(e))
            
    def set_burst(self, b):
        self["burst"] = b
        self.check_burst(self)
        
    def set_ratio(self, r):
        self["ratio"] = r
        self.check_ratio(self)
    
    def set_width(self, w):
        self["width"] = w
        self.check_width(self)

    def set_base_address(self, b):
        self["base_address"] = b
        self.check_base_address(self)
        
    def get_macros(self):
        return self["macros"]
        
    @classmethod
    def parse_oct_pins(cls, e):
        pins = parse_list(e, "oct_pins")
        for p in pins:
            if(not Tinker.is_valid_verilog_name(p)):
                Tinker.value_error_xml("oct_pins", p, "Valid Verilog Names",
                                       ET.tostring(e))
        return pins

    @classmethod
    def parse_grouping(cls, e):
        ids = parse_list(e, "grouping")
        for i in ids:
            if(not Tinker.is_id(i)):
                Tinker.value_error_xml("grouping", i, "Alphabetic Characters",
                                       ET.tostring(e))
        return ids

def int2ratio(i):
    if(i == 1):
        return "Full"
    if(i == 2):
        return "Half"
    if(i == 4):
        return "Quarter"
    return "Invalid"

def ratio2int(ratio):
    if(ratio =="Full"):
        return 1
    if(ratio =="Half"):
        return 2
    if(ratio =="Quarter"):
        return 4
    return 0
