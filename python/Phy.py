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
import abc, sys

class Phy(IP.IP):
    _C_BURST_WIDTHS = [] # TODO: Burst widths should be power of 2
    _C_BURST_DEFAULT = 0 # TODO: Burst widths should be power of 2
    _C_CLOCK_RATIOS = [] 
    _C_MAX_DATA_BUS_WIDTH = 2048
    
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
        check_frequency(d["fmax_mhz"])
        check_frequency(d["fref_mhz"])
        check_dq_pins(d["dq_pins"])
        check_pow_2_dq_pins(d["pow2_dq_pins"])
        check_bandwidth_bs(d["bandwidth_bs"])

        return
        
    def parse(self,e):
        d = {}

        id = parse_id(e)
        fref_mhz = Tinker.parse_float(e, "fref_mhz", ET.tostring)
        fmax_mhz = Tinker.parse_float(e, "fmax_mhz", ET.tostring)
        dq_pins = Tinker.parse_int(e, "dq_pins", ET.tostring)
        macros = Tinker.parse_macros(e, ET.tostring)

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
        d["bandwidth_bs"] = int((d["fmax_mhz"] * 10**6 * self._C_RATE * pow2_dq_pins) / 8)

        Phy.validate(d)
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
        # TODO: Tinker.key_error
        # These should be passed in from the system..
        self.check_base_address(d.get("base_addr"));
        self.check_oct_pin(d.get("oct_pin"))
        self.check_role(d.get("role"))

        # Truly optional defaults
        self.check_ratio(d.get("ratio"))
        self.check_data_bus_width(d.get("width"));
        self.check_max_burst(d.get("maxburst"))
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

    def check_ratio(ratio):
        if(ratio is None):
            sys.exit("Ratio cannot be unspecified in configuration")
        if(ratio not in self._C_CLOCK_RATIOS):
            sys.exit("Invalid Ratio %s Specified for Phy" % ratio)

    def check_role(role):
        if(role is None):
            sys.exit("Role cannot be unspecified in configuration")
        if(role not in self["roles"]):
            sys.exit("Invalid Role %s Specified for Phy" % role)

    def check_base_address(self, base):
        if(base is None):
            sys.exit("Base address cannot be unspecified in configuration")
        if(not Tinker.is_in_range(base, 0, (2 ** 64) - self["size"])):
            sys.exit("Invalid Base Address %x Specified for Phy" % base)
        
    def check_data_bus_width(width):
        if(width is None):
            sys.exit("Data-Bus width cannot be unspecified in configuration")
        if(not Tinker.is_pow_2(width)):
            sys.exit("Invalid Non-power-of-2 Bus-Width %x Specified for Phy" % width)
        if(width % self["pow2_dq_width"] != 0):
            sys.exit("Bus-width %x must be a multiple of the POW2 DQ Pins in Phy" % width)
        if(not Tinker.is_in_range(width, 0, self._C_MAX_DATA_BUS_WIDTH)):
            sys.exit("Invalid Bus-Width %x Specified for Phy" % width)

    def check_max_burst(burst):
        if(burst is None):
            sys.exit("Burst cannot be unspecified in configuration")
        if(not Tinker.is_pow_2(burst)):
            sys.exit("Invalid Max-Burst paramter %x Specified for Phy" % burst)
        if(burst not in self._C_BURST_WIDTHS):
            sys.exit("Invalid Max-Burst parameter %x Specified for Phy" % burst)

def check_frequency(f_hz):
    if(not Tinker.is_in_range(f_hz, 0, 10**9)):
        sys.exit("Invalid Frequency %f Specified for Phy" % f_hz)

def check_dq_pins(p):
    if(not Tinker.is_in_range(p, 0, 128)):
        sys.exit("Invalid Number of DQ (Data) Pins %d Specified for Phy" % p)
        
def check_pow_2_dq_pins(p):
    if(not Tinker.is_in_range(p, 0, 128)):
        sys.exit("Invalid Power-of-2 DQ (Data) Pins %d Specified for Phy" % p)
    if(not Tinker.is_pow_2(p)):
        sys.exit("Invalid Power-of-2 DQ (Data) Pins %d is not a power of 2" % p)

def check_bandwidth_bs(s):
    if(not Tinker.is_in_range(s,0,1<<32)):
        sys.exit("Invalid Size %s Specified for Phy" % s)

def check_size(s):
    if(not Tinker.is_in_range(s,0,1<<32)):
        sys.exit("Invalid Size %s Specified for Phy" % s)
    if(not Tinker.is_pow_2(s)):
        sys.exit("Invalid Non-power-of-2 Size %s Specified for Phy" % s)

def parse_roles(e):
    roles = ["primary", "secondary","independent"]
    s = Tinker.parse_string(e,"roles", ET.tostring)
    mem_roles = Tinker.parse_list_from_string(s)
    for mr in mem_roles:
        if(mr not in roles):
            sys.exit("Invalid role \"%s\" found in roles attribute:\n  %s" % (mr, ET.tostring(e)))
    return mem_roles
    
def parse_grouping(e):
    s = Tinker.parse_string(e, "grouping", ET.tostring)
    ids = Tinker.parse_list_from_string(s)
    for id in ids:
        if(not Tinker.is_alphachar(id)):
            sys.exit("Invalid grouping id \"%s\" found in attribute:\n%s" % (id,ET.tostring(e)))
    return ids

def parse_ports(e):
    ports = ["r", "w", "rw"]
    s = Tinker.parse_string(e,"ports", ET.tostring)
    mem_ports = Tinker.parse_list_from_string(s)
    for mp in mem_ports:
        if(mp not in ports):
            sys.exit("Invalid port \"%s\" found in ports attribute:\n  %s" % (mp, ET.tostring(e)))
    return mem_ports

def parse_ratios(e):
    ratios = ["Quarter", "Half","Full"]
    s = Tinker.parse_string(e, "ratios", ET.tostring)
    mem_ratios = Tinker.parse_list_from_string(s)
    for mr in mem_ratios:
        if(mr not in ratios):
            sys.exit("Invalid ratio \"%s\" found in ratios attribute:\n  %s" % (mr, ET.tostring(e)))
    return mem_ratios

def parse_oct_pins(e):
    s = Tinker.parse_string(e, "oct_pins", ET.tostring)
    pins = Tinker.parse_list_from_string(s)
    for p in pins:
        if(not Tinker.is_valid_verilog_name(p)):
            sys.exit("Invalid OCT pin \"%s\" found in oct_pins attribute:\n  %s" % (p, ET.tostring(e)))
    return pins

def parse_id(e):
    id = Tinker.parse_string(e, "id", ET.tostring)
    if(not Tinker.is_alphachar(id)):
        sys.exit("Invalid ID \"%s\" found in id attribute:\n %s" % (id, ET.tostring(e)))
    return id
