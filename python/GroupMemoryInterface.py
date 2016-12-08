import DDR, QDR
import Tinker, MemoryInterface
import sys
from Interface import *
import xml.etree.ElementTree as ET
from math import log
class GroupMemoryInterface(Interface):
    _C_INTERFACE_KEYS = set(["type", "role", "quantity",
                         "interfaces", "burst", "ratio", "width"])
    _C_INTERFACE_TYPES = set(["DDR3","QDRII"])
    _C_INTERFACE_ROLES = set(["primary", "secondary"])
    _C_INTERFACE_RATIOS = set(["Half", "Quarter", "Full"])
    _C_INTERFACE_WIDTH_RANGE = (8,1024)
    _C_INTERFACE_BURST_RANGE = (1,10)
    _C_SIZE_RANGE= (0,1<<32)
    _C_INTERFACE_MHZ_RANGE = (1,300)
    def __init__(self, desc, id):
        """Construct a generic Interface Object

        Arguments:

        desc -- a dictionary object containing a description of this
        interface

        """
        # self.check_id(id) # TODO
        self.__id = id
        super(GroupMemoryInterface,self).__init__(desc)
        
    @classmethod
    def parse(cls, desc):
        """
        
        Parse the description of this IP object from an dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        # Try to parse interfaces -- if it fails, return
        d = super(GroupMemoryInterface,cls).parse(desc)
        # Required Description Parameters
        q = None
        ifs = None
        if("quantity" in desc):
            q = cls.parse_quantity(desc)
        if("interfaces" in desc):
            ifs = cls.parse_interfaces(desc)

        if(ifs is not None):
            d["interfaces"] = ifs
            d["quantity"] = len(ifs)
            if(q is not None and q != len(ifs)):
                # TODO: is this the right error message?
                Tinker.value_error_map("quantity", q, str(len(ifs)))
            if((set(desc.keys()) - cls._C_INTERFACE_KEYS) == set()):
                pass
            elif(set(ifs) == (set(desc.keys()) - cls._C_INTERFACE_KEYS)):
                for i in ifs:
                    if(desc[i]["role"] == "primary"):
                        d["primary"] = i
                for i in ifs:
                    # Hack...
                    if(desc[i]["role"] != "primary"):
                        desc[i]["master"] = d["primary"]
                    d[i] = MemoryInterface.MemoryInterface(desc[i])
            else:
                sys.exit("Error! Interfaces \"%s\" were missing keys"
                         % str(list(set(desc.keys())
                                    - cls._C_INTERFACE_KEYS
                                    - set(ifs))))
        elif(q is not None):
            d["quantity"] = q
        else:
            sys.exit("Failed to find an enumeration of memory interfaces in %s"
                     % str(desc))

        # Optional Description Parameters
        if("role" in desc):
            d["role"] = cls.parse_role(desc)
            
        if("burst" in desc):
            d["burst"] = cls.parse_burst(desc)

        if("ratio" in desc):
            d["ratio"] = cls.parse_ratio(desc)

        if("width" in desc):
            d["width"] = cls.parse_width(desc)

        if("name" in desc):
            d["name"] = cls.parse_name(desc)
        return d
    
    @classmethod
    def parse_name(cls, d):
        n = cls.parse_string(desc, "name")
        return n
    
    @classmethod
    def check_name(cls, d):
        n = cls.parse_string(d, "name")
        if(not Tinker.is_valid_verilog_name(n)):
            Tinker.value_error_map("name", n, "Valid Verilog Names",
                                   Tinker.tostr_dict(d))
        if(len(n) > cls._C_):
            Tinker.value_error_map("name", n, "Strings less than 32 characters",
                                   Tinker.tostr_dict(d))
            
        return n
    
    @classmethod
    def parse_burst(cls,d):
        b = parse_int(d, "burst")
        if(not Tinker.is_in_range(b,cls._C_INTERFACE_BURST_RANGE[0],
                                  cls._C_INTERFACE_BURST_RANGE[1])):
            Tinker.value_error_map("burst", str(b),
                               "range(%d, %d)"
                               % (cls._C_INTERFACE_BURST_RANGE[0],
                                  cls._C_INTERFACE_BURST_RANGE[1]),
                                  Tinker.tostr_dict(d))
        return b
    
    @classmethod
    def parse_master(cls, d):
        return parse_string(d, "master")

    @classmethod
    def parse_interfaces(cls, d):
        l = []
        ifs = parse_list(d, "interfaces")
        for i in ifs:
            if(ifs.count(i) > 1):
                sys.exit("Error! Interface \"%s\" was not unique in list %s"
                         % (i, str(ifs)))
            l.append(i)
        return l

    @classmethod
    def parse_interface_keys(cls, desc):
        k = set(desc.keys())
        err = (k - cls._C_MEMORY_KEYS)
        if(err != set()):
            print "In description:"
            Tinker.tostr_dict(desc)
            sys.exit("Error! Unknown keys: %s" % str(list(err)))
        return k

    @classmethod
    def parse_interface(cls, desc):
        d = dict()
        cls.parse_interface_keys(desc)
        d["role"] = cls.parse_role(desc)
        if("master" in desc):
            d["master"] = cls.parse_master(desc)
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
        super(GroupMemoryInterface,cls).validate(d)
        cls.check_interfaces(d)
        
        if("interfaces" in d):
            cls.check_roles(d)
            
        if("role" in d):
            cls.check_role(d)

        # TODO: Check primary

    @classmethod
    def check_interfaces(cls,d):
        cls.check_quantity(d)
        p = None
        q = d["quantity"]
        if("interfaces" not in d):
            ifs = None
        else:
            ifs = parse_list(d,"interfaces")
            
        if(ifs is not None and len(ifs) != q):
            Tinker.value_error_map("quantity", str(q), str(len(ifs)),
                                   Tinker.tostr_dict(d))
        elif(ifs is None or set(ifs) & set(d.keys()) == set()):
            pass
        elif((set(ifs) < set(d.keys()))):
            for i in ifs:
                d[i].validate(d[i])
                d[i].check_role(d[i])
                if(d[i]["role"] == "primary" ):
                    if(p != None):
                        Tinker.value_error_map("role", d[i]["role"],
                                               "Non-primary role",
                                               Tinker.tostr_dict(cls))
                    p = i
        else:
            sys.exit("Error! interfaces cannot be partially enumerated subset")


    @classmethod
    def check_roles(cls, d):
        cls.check_interfaces(d)
        ifs = d["interfaces"]
        pid = None
        others = []
        for i in ifs:
            r = d[i]["role"]
            if(r == "primary" and pid != None):
                sys.exit("Error! Two primary interfaces \"%s\" and \"%s\" found."
                         % (pid, i))
            elif(r == "primary"):
                pid = i
            else:
                others.append(i)

        for i in others:
            # TODO: Check master?
            m = d[i]["master"]
            r = d[i]["role"]
            if(m != pid):
                print "In key-value map:"
                print Tinker.tostr_dict(d)
                sys.exit("Error! Interface \"%s\" has role \"%s\" but " % (i, r)
                        + "specified master \"%s\" does not match primary \"%s\"" % (m, pid))
        
    def implement(self, b):
        """

        Implement the Interface described by this object using the Board
        object describing the IP available on this board. 

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        self.validate(self)
        self.check_quantity(self)
        if("interfaces" in self):
            self.check_interfaces(self)
        else:
            self["interfaces"] = []
            # TODO: Check interfaces, type
            ifs = b[self["type"]]["interfaces"]
            q = self["quantity"]
            if(q > len(ifs)):
                Tinker.value_error_map("quantity", str(q),
                                       "Range(1, %d)" % str(len(ifs)),
                                       Tinker.tostr_dict(self))
            default = b[self["type"]]["default"]
            d = {"role":"primary"}
            self["primary"] = default
            self["interfaces"].append(default)
            self[default] = MemoryInterface.MemoryInterface(d)
            ifs.remove(default)
            q -= 1

            for i in ifs:
                if(q <= 0):
                    break
                
                p = b[self["type"]][i]
                d = {}
                if("independent" in p["roles"]):
                    d["role"] = "independent"
                    d["master"] = default
                elif("secondary" in p["roles"] and default in p["group"]):
                    d["role"] = "secondary"
                    d["master"] = default
                else:
                    continue
                q -= 1
                self[i] = MemoryInterface.MemoryInterface(d)
                self["interfaces"].append(i)
            if(q > 0):
                print "In Key-Value Map"
                print Tinker.tostr_dict(self)
                sys.exit("Error! Not enough independent or capable "+
                         "secondary interfaces to implement memory group")
        ba = 0
        sz = 0
        for i in self["interfaces"]:
            self[i].implement(b[self["type"]][i])
            self[i] = self[i]["IP"]
            
            if("burst" in self):
                self[i].set_burst(self["burst"])
            if("ratio" in self):
                self[i].set_ratio(self["ratio"])
            if("width" in self):
                self[i].set_ratio(self["width"])
                
        
        self.__configure()
        pass

    def __configure(self):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        sz = 0
        bw = 0
        for i in self["interfaces"]:
            self[i].check_size(self[i])
            self[i].check_bandwidth_bs(self[i])
            self[i].check_role(self[i])
            self[i].check_fpga_frequency(self[i])
            # TODO: I don't like relying on dict...
            sz += self[i]["size"]
            bw +=self[i]["bandwidth_bs"]
            if(self[i]["role"] == "primary" ):
            # TODO: Check Primary
            #    if("primary" in self):
            #        Tinker.value_error_map("role", self[i]["role"], "Non-primary role",
            #                               Tinker.tostr_dict(self))
            #    self["primary"] = i
                self["freq_mhz"] = self[i]["fpga_mhz"]
            
        self["size"] = sz
        self["bandwidth"] = bw
        if0 = self[self["interfaces"][0]]
        if0.check_width(if0)
        w = if0["width"]
        self["width"] = w
        if0.check_burst(if0)
        b = if0["burst"]
        self["burst"] = b

    def set_role(self, r):
        self["role"] = r
        self.check_role(self)
        
    def set_config_addr(self, a):
        self["config_addr"] = a
        # TODO: Check config addr
        
    def set_base_address(self, b):
        self.check_size(self)
        self["base_address"] = b
        for i in self["interfaces"]:
            self[i].set_base_address(b)
            b += self[i]["size"]
        self.check_base_address(self)

    @classmethod
    def check_base_address(cls, d):
        cls.check_size(d)
        sz = d["size"]
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
            Tinker.value_error_map("size", str(sz),
                                   "Integer powers of 2",
                                   Tinker.tostr_dict(d))
    def verify(self):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        
        if0 = self[self["interfaces"][0]]
        if0.check_width(if0)
        w = if0["width"]
        if0.check_burst(if0)
        b = if0["burst"]
        for i in self["interfaces"]:
            self[i].verify()
            if(self[i]["width"] != w):
                Tinker.value_error("width", self[i]["width"], str(w),
                                   Tinker.tostr_dict(self))
            if(self[i]["burst"] != b):
                Tinker.value_error("burst", self[i]["burst"], str(b),
                                   Tinker.tostr_dict(self))
        self.check_size(self)
        self.check_frequency(self)
        self.check_roles(self)
        self.check_interfaces(self)
        self.check_role(self)
        # TODO: bandwidth, width

    @classmethod
    def parse_primary(cls, d):
        p = parse_string(d, "primary")
        return p
        # TODO : Valid ID
        
    @classmethod
    def check_primary(cls, d):
        cls.parse_primary(d)
        
    @classmethod
    def parse_ratio(cls, desc):
        r = parse_string(desc, "ratio")
        if(r not in cls._C_INTERFACE_RATIOS):
            Tinker.value_error_map("ratio", str(r), str(cls._C_INTERFACE_RATIOS),
                                   Tinker.tostr_dict(desc))
        return r

    @classmethod
    def check_ratio(cls, d):
        parse_ratio(d)

    @classmethod
    def parse_width(cls, d):
        w = parse_int(d, "width")
        if(not Tinker.is_in_range(w,
                                  cls._C_INTERFACE_WIDTH_RANGE[0],
                                  cls._C_INTERFACE_WIDTH_RANGE[1])):
            Tinker.value_error_map("width", str(w),
                                   "range(%d, %d)"
                                   % (cls._C_INTERFACE_WIDTH_RANGE[0],
                                      cls._C_INTERFACE_WIDTH_RANGE[1]),
                                      Tinker.tostr_dict(d))
        return w
    
    @classmethod
    def check_width(cls,d):
        w = parse_int(d, "width")
        if(not Tinker.is_in_range(w,
                                  cls._C_INTERFACE_WIDTH_RANGE[0],
                                  cls._C_INTERFACE_WIDTH_RANGE[1])):
            Tinker.value_error_map("width", str(w),
                                   "range(%d, %d)"
                                   % (cls._C_INTERFACE_WIDTH_RANGE[0],
                                      cls._C_INTERFACE_WIDTH_RANGE[1]),
                                      Tinker.tostr_dict(d))
    @classmethod
    def check_frequency(cls, d):
        freq = d.get("freq_mhz")
        freq_min = cls._C_INTERFACE_MHZ_RANGE[0]
        freq_max = cls._C_INTERFACE_MHZ_RANGE[1]
        if(freq is None):
            Tinker.key_error("freq_mhz", Tinker.tostr_dict(d))
        if(not Tinker.is_in_range(freq, freq_min, freq_max)):
            Tinker.value_error_map("freq_mhz", str(freq),
                                   "Range(0x%x, 0x%x)" % (freq_min, freq_max),
                                   Tinker.tostr_dict(d))

    def __get_global_mem_element(self, version, verbose):
        e = ET.Element("global_mem")
        
        e.set("interleaved_bytes", str((self["burst"] * self["width"]/8)))
        e.set("max_bandwidth", str(self["bandwidth"]/1000000))
        e.set("config_addr", str(hex(self["config_addr"])))
        e.set("name", self["type"] + "_" + self.__id) #TODO: Interface Name
        if(self["role"] == "primary" and version > 14.1):
            e.set("default","1")
        if(verbose):
            e.set("base_address",str(hex(self["base_address"])))
            e.set("quantity",str(self["quantity"]))
            e.set("width",str(self["width"]))
            e.set("sys_id",str(self.__id))
            e.set("type",self["type"])
            e.set("maxburst",str(self["burst"]))
            e.set("addr_width",str(int(log(self["size"],2))))
            e.set("role",self["role"])
        return e

    def get_macros(self, version, verbose):
        l = []
        for i in self["interfaces"]:
            l += self[i].get_macros()
        return l
       
    def get_global_mem_element(self, version, verbose):
        e = self.__get_global_mem_element(version, verbose)
        for i in self["interfaces"]:
            #TODO: Change naming, kernel interface should use type
            e.append(self[i].get_interface_element(self.__id, version, verbose))
        return e

    def get_interface_elements(self, version, verbose):
        return [self.__get_snoop_interface(self.__id, version, verbose)]

    def get_pin_elements(self, version, verbose):
        l = []
        for i in self["interfaces"]:
            #TODO: Change naming, pin interface should use type
            l += self[i].get_pin_elements(self.__id, version, verbose)
        return l
    
    def __get_snoop_interface(self, sid, version, verbose):
        w = self["width"]
        b = self["burst"]
        s = self["size"]
        
        e = ET.Element("interface")
        e.set("name", "tinker")
        e.set("port", "acl_internal_snoop_%s" % str(sid)) # TODO: Update in TCL
        e.set("type", "streamsource")
        e.set("enable", "SNOOPENABLE")
        e.set("clock", "tinker.kernel_clk")
        # This arcane calcuation can be found in the TCL files from altera
        e.set("width",str(int(log(s)/log(2) - log(w/8)/log(2) + b + 2)))

        return e
