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
import Tinker, Memory
import abc, sys
from IP import parse_list, parse_string, parse_int, parse_id, parse_float, parse_macros, IP
from Memory import Memory, parse_ratios, parse_ports, parse_roles, parse_grouping
class Phy(IP):
    _C_BURST_WIDTHS = [] # TODO: Burst widths should be power of 2
    _C_BURST_DEFAULT = 0 # TODO: Burst widths should be power of 2
    _C_CLOCK_RATIOS = [] 
    _C_MAX_DATA_BUS_WIDTH = 2048
    _C_FMAX_MHZ_RANGE = (1,2000)
    _C_FREF_MHZ_RANGE = (1,500)
    _C_DQ_PIN_RANGE = (0,128)
    _C_POW2_DQ_PIN_RANGE = (0,128)
    _C_BANDWIDTH_BS_RANGE= (0,1<<32)
    _C_SIZE_RANGE= (0,1<<32)
    
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
        cls.check_size(d)
        cls.check_frequency(d)
        cls.check_dq_pins(d)
        cls.check_pow_2_dq_pins(d)
        cls.check_bandwidth_bs(d)

        return
        
    @classmethod
    def parse(cls,e):
        d = {}

        id = parse_id(e)
        fref_mhz = parse_float(e, "fref_mhz")
        fmax_mhz = parse_float(e, "fmax_mhz")
        dq_pins = parse_int(e, "dq_pins")
        macros = parse_macros(e)

        d["id"] = id
        d["fmax_mhz"] = fref_mhz
        d["fref_mhz"] = fref_mhz
        d["dq_pins"] = dq_pins
        d["macros"] = macros
        
        roles = parse_roles(e)
        group = parse_grouping(e)
        group.remove(id)
        ports = parse_ports(e)
        ratios = parse_ratios(e)
        octs = parse_oct_pins(e)

        d["roles"] = roles
        d["group"] = group
        d["ports"] = ports
        d["ratios"] = ratios
        d["oct_pins"] = octs

        pow2_dq_pins = int(2 ** Tinker.clog2(dq_pins))
        d["pow2_dq_pins"] = pow2_dq_pins
        d["bandwidth_bs"] = int((d["fmax_mhz"] * 10**6 * cls._C_RATE * pow2_dq_pins) / 8)

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
        d.update(self)
        # TODO: Check passed-in parameters
        d = self.__fill(d)
        d = self.verify(d)
        self.update(d)

    def __fill(self, d):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """

        if("ratio" not in d and "width" not in d):
            d["ratio"] = self.get_default_ratio()
            d["width"] = int(self["pow2_dq_pins"] / Tinker.ratio2float(d["ratio"])) * self._C_RATE
            
        elif("width" in d):
            d["ratio"] = Tinker.int2ratio(d["width"]/ self["pow2_dq_pins"])

        elif("ratio" in d):
            d["width"] = int(self["pow2_dq_pins"] / Tinker.ratio2float(d["ratio"])) * self._C_RATE
            
        if("burst" not in d):
            d["burst"] = self.get_default_burst()

    def verify(self, d):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        # TODO: Check should take the dictionary.
        # These should be passed in from the system..
        self.check_base_address(d);
        self.check_oct_pin(d)
        self.check_role(d)

        # Truly optional defaults
        self.check_ratio(d)
        self.check_data_bus_width(d);
        self.check_max_burst(d)
        return d

    def get_interface(self, id, verbose=False):
        self.verify(self)
        i = ET.Element("interface")

        i.set("name","tinker")
        i.set("type","slave")
        i.set("address", str(hex(self["base_addr"])))
        i.set("size", str(hex(self["size"])))
        i.set("width", str(self["width"])) 
        i.set("maxburst", str(self["burst"]))
        if(verbose):
            self.__set_verbose_interface(i)
            
        return i
    
    def __set_verbose_interface(self, i):
        i.set("id", self["id"])
        i.set("ratio", self["ratio"])
        i.set("role", self["role"])
        if(self["role"] == "secondary"):
            i.set("shared","pll,dll,oct")
            i.set("primary",self["primary"])
        elif(self["role"] == "independent"):
            i.set("shared",self["oct_pin"])
            i.set("primary",self["primary"])
        else:
            i.set("shared","")

        i.set("mem_frequency_mhz",str(self["fmax_mhz"]))
        i.set("ref_frequency_mhz",str(self["fref_mhz"]))
            
        return r

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

    # TODO: Why are these objectmethods?
    def check_role(self, d):
        role = d.get("role")
        if(role is None):
            Tinker.key_error("role", Tinker.tostr_dict(d))
        if(role not in self["roles"]):
            Tinker.value_error_map("role", role, self["roles"],
                                   Tinker.tostr_dict(d))

    # TODO: Why are these objectmethods?
    def check_oct_pin(self, d):
        oct_pin = d.get("oct_pin")
        if(oct_pin is None):
            Tinker.key_error("oct_pin", Tinker.tostr_dict(d))
        if(oct_pin not in self["oct_pins"]):
            Tinker.value_error_map("oct_pin", role, self["oct_pins"],
                                   Tinker.tostr_dict(d))

    # TODO: Why are these objectmethods? Should they be called validate?
    def check_base_address(self, d):
        self.check_size(d)
        sz = self["size"]
        base = d.get("base_address")
        if(base is None):
            Tinker.key_error("base_address", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(base, 0, (2 ** 64) - sz)):
            Tinker.value_error_map("base_address", str(base),
                                   "Range(%x, %x)" % (0, (2**64) - sz),
                                   Tinker.tostr_dict(d))
        if((base % sz) != 0):
            Tinker.value_error_map("base_address", str(base),
                                   "Multiples of %x (Size)" % sz,
                                   Tinker.tostr_dict(d))
    
    @classmethod
    def check_data_bus_width(cls, d):
        check_pow_2_dq_pins(d)
        p2dqp = d["pow2_dq_pins"]
        width = d.get("width")
        if(width is None):
            Tinker.key_error("width", Tinker.tostr_dict(d))
        if(not Tinker.is_pow_2(width)):
            Tinker.value_error_map("width", str(width),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))
        if(width % p2dqp != 0):
            Tinker.value_error_map("width", str(width),
                                   "Multiple of %x (Pow2 DQ Width)" % p2dqp,
                                   Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(width, 0, cls._C_MAX_DATA_BUS_WIDTH)):
            Tinker.value_error_map("width", str(width),
                                   str(list(cls._C_MAX_DATA_BUS_WIDTH)),
                                   Tinker.tostr_dict(d))
    @classmethod
    def check_max_burst(cls, d):
        burst = d.get("maxburst")
        if(burst is None):
            Tinker.key_error("maxburst", Tinker.tostr_dict(d))
        if(not Tinker.is_pow_2(burst)):
            Tinker.value_error_map("maxburst", str(burst),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))
        if(burst not in cls._C_BURST_WIDTHS):
            Tinker.value_error_map("maxburst", str(burst),
                                   str(list(cls._C_BURST_WIDTHS)),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_frequency(cls, d):
        fmax = d.get("fmax_mhz")
        fmax_min = cls._C_FMAX_MHZ_RANGE[0]
        fmax_max = cls._C_FMAX_MHZ_RANGE[1]
        if(fmax is None):
            Tinker.key_error("fmax_mhz", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(fmax, fmax_min, fmax_max)):
            Tinker.value_error_map("fmax_mhz", str(fmax),
                                   "Range(%x, %x)" % (fmax_min, fmax_max),
                                   Tinker.tostr_dict(d))
    
        fref = d.get("fref_mhz")
        fref_min = cls._C_FREF_MHZ_RANGE[0]
        fref_max = cls._C_FREF_MHZ_RANGE[1]
        if(fref is None):
            Tinker.key_error("fref_mhz", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(fref, fref_min, fref_max)):
            Tinker.value_error_map("fref_mhz", str(fref),
                                   "Range(%x, %x)" % (fref_min, fref_max),
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
                                   "Range(%x, %x)" % (dq_min, dq_max),
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
                                   "Range(%x, %x)" % (pdq_min, pdq_max),
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
        if(not Tinker.is_in_range(bw,0,1<<32)):
            Tinker.value_error_map("bandwidth_bs", str(bw),
                                   "Range(%x, %x)" % (bw_min, bw_max),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_size(cls, d):
        sz = d.get("size")
        sz_min = cls._C_SIZE_RANGE[0]
        sz_max = cls._C_SIZE_RANGE[1]
        if(sz is None):
            Tinker.key_error("size", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(sz, sz_min, sz_max)):
            Tinker.value_error_map("size", str(sz),
                                   "Range(%x, %x)" % (sz_min, sz_max),
                                    Tinker.tostr_dict(d))
        if(not Tinker.is_pow_2(sz)):
            Tinker.value_error_map("pow2_dq_pins", str(sz),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))
    
def parse_oct_pins(e):
    pins = parse_list(e, "oct_pins")
    for p in pins:
        if(not Tinker.is_valid_verilog_name(p)):
            Tinker.value_error_xml("oct_pins", p, "Valid Verilog Names",
                                   ET.tostring(e))
    return pins


