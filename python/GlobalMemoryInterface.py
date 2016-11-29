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
import DDR, QDR
import Tinker, GroupMemoryInterface
import sys
from Interface import *
class GlobalMemoryInterface(Interface):
    _C_INTERFACE_KEYS = set(["interfaces", "type"])
    _C_INTERFACE_TYPES = set(["DMA"])
    _C_INTERFACE_ROLES = set(["primary", "secondary"])

    # TODO: minimum size requirement too
    def __init__(self, desc):
        """Construct a generic Interface Object

        Arguments:

        desc -- a dictionary object containing a description of this
        interface

        """
        super(GlobalMemoryInterface,self).__init__(desc)

    @classmethod
    def parse(cls, desc):
        """
        
        Parse the description of this IP object from an dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        d = super(GlobalMemoryInterface,cls).parse(desc)
        d["interfaces"] = cls.parse_interfaces(desc)
        d["quantity"] = cls.parse_quantity(desc)
        for i in d["interfaces"]:
            d[i] = GroupMemoryInterface.GroupMemoryInterface(desc[i])
        return d
            
    @classmethod
    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this Interface

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        super(GlobalMemoryInterface,cls).validate(d)
        cls.check_interfaces(d)
        cls.check_quantity(d)
        cls.check_roles(d)

    @classmethod
    def check_roles(cls, d):
        cls.check_interfaces(d)
        ifs = d["interfaces"]
        pid = None
        spec = (d[ifs[0]].get("role") != None)
        for i in ifs:
            r = d[i].get("role")
            if(r is None and spec is True):
                Tinker.key_error("role",str(d[i]))
            elif(r != None and spec is False):
                print "In description:"
                Tinker.print_description(d)
                sys.exit("Roles must be specified for all Memory Interfaces, or none of them.")
            elif(r != None and r not in cls._C_INTERFACE_ROLES):
                Tinker.value_error_map("role", str(r), str(cls._C_INTERFACE_ROLES),
                                       Tinker.tostr_dict())
            elif(r != None and r == "primary" and pid != None):
                print "In description:"
                Tinker.print_description(d)
                sys.exit("Error! Two primary interfaces \"%s\" and \"%s\" found."
                         % (pid, i))
            elif(r == "primary"):
               pid = i

    def implement(self, b):
        """

        Implement the Interface described by this object using the Board
        object describing the IP available on this board. 

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        self.__fill(b)
        self.validate(b)
        self.verify(self)

    def __fill(self, d):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        pass

    @classmethod
    def verify(cls, d):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        #TODO: Role must be completely specified by the time implementation happens
        pass

    @classmethod
    def parse_quantity(cls, desc):
        ifs = cls.parse_interfaces(desc)
        return len(ifs)
    
    @classmethod
    def parse_interfaces(cls, desc):
        ifs = parse_list(desc, "interfaces")
        if(ifs == []):
            print "In description:"
            Tinker.print_description(d)
            sys.exit("Error! A Global Memory must have more than one interface!")
            
        for i in ifs:
            if(ifs.count(i) > 1):
                sys.exit("Error! Interface \"%s\" was not unique in list %s"
                         % (i, str(ifs)))
            parse_dict(desc, i)
        return ifs

    @classmethod
    def check_quantity(cls, d):
        super(GlobalMemoryInterface,cls).check_quantity(d)
        
        cls.check_interfaces(d)
        ifs = cls.parse_interfaces(d)
        q = parse_int(d, "quantity")
        if(q != len(ifs)):
            Tinker.value_error_map("quantity",str(q),str(ifs),
                                   Tinker.tostr_dict(d))

    @classmethod
    def check_interfaces(cls,d):
        ifs = parse_list(d, "interfaces")
            
        if(ifs == []):
            print "In description:"
            Tinker.print_description(d)
            sys.exit("Error! A Global Memory must have more than one interface!")

        for i in ifs:
            if(ifs.count(i) > 1):
                sys.exit("Error! Interface \"%s\" was not unique in list %s"
                         % (i, str(ifs)))
            parse_dict(d,i)
            d[i].validate(d[i])

    def build_spec(self,spec, n, base, specification=False):
        s = spec.get_info()
        r = ET.Element("global_mem", attrib={"name": self.info["type"] + "_" + str(n)})

        burst = s[n].get("Burst","16")
        
        if0 = s[n]["interfaces"][0]
        width = int(1/(Tinker.ratio2float(s[n]["Ratio"])) * self.info[if0]["pow2_dq_pins"] * self.info[if0]["clock_ratio"])
        intbytes = int(burst) * width / 8
        r.set("interleaved_bytes", str(intbytes))
        if(n == "0"):
            r.set("config_addr", "0x018")
            if(specification): # Reintroduce in 15.1
                r.set("default","1")
        else:
            r.set("config_addr", hex(int("0x100",16) + (int(n)-1) * int("0x18",16)))

        size = 0
        bandwidth = 0
        for id in s[n]["interfaces"]:
            bandwidth += self.info[id]["bandwidth_bs"]
            i = self.ifs[id]
            e = i.build_spec(spec,n,id,base+size,burst,width,specification=specification)
            size += int(s[n][id]["Size"],16)
            r.append(e);
        
        r.set("max_bandwidth", str(int(bandwidth)/1000000))
        if(specification):
            r.set("base_address",hex(base))
            r.set("quantity",str(len(s[n]["interfaces"])))
            r.set("width",str(width))
            r.set("sys_id",str(n))
            r.set("type",s[n]["type"])
            r.set("maxburst",str(burst))
            r.set("addr_width",str(int(math.log(size,2))))
            r.set("role",s[n]["Role"])
        return r
    
