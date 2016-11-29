import DDR, QDR
import Tinker, MemoryInterface
import sys
from Interface import *
class GroupMemoryInterface(Interface):
    _C_INTERFACE_KEYS = set(["type", "role", "quantity",
                         "interfaces", "burst", "ratio"])
    _C_INTERFACE_BURST_RANGE = (1,10)
    _C_INTERFACE_TYPES = ["DDR3","QDRII"]
    _C_INTERFACE_ROLES = ["primary", "secondary"]
    #_C_MEMORY_ROLES = ["primary", "secondary", "independent"]
    #_C_MEMORY_KEYS = set(["role","master"])
    def __init__(self, desc):
        """Construct a generic Interface Object

        Arguments:

        desc -- a dictionary object containing a description of this
        interface

        """
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
                    d[i] = MemoryInterface.MemoryInterface(desc[i])
                    #cls.parse_interface(desc[i])
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
        # TODO: is there a more elegant way to get optional desc keys
        if("role" in desc):
            d["role"] = cls.parse_role(desc)
            
        if("burst" in desc):
            d["burst"] = cls.parse_burst(desc)
        
        if("ratio" in desc):
            d["ratio"] = cls.parse_burst(desc)
        return d

    
    @classmethod
    def parse_burst(cls,d):
        b = parse_int(d, "burst")
        if(not Tinker.is_in_range(b,cls._C_INTERFACE_BURST_RANGE[0],
                              cls._C_INTERFACE_BURST_RANGE[1])):
            Tinker.value_error_map("burst", str(b),
                               "range(%d, %d)"
                               % (str(cls._C_INTERFACE_BURST_RANGE[0]),
                                  str(cls._C_INTERFACE_BURST_RANGE[1])),
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
            # TODO: What is a valid interface ID?
            # if(not Tinker.is_valid_verilog_name(i)):
            #    sys.exit("Error! Invalid name \"%s\" in interface list: %s"
            #             % (i,str(ifs)))
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
        

    @classmethod
    def check_interfaces(cls,d):
        cls.check_quantity(d)

        q = d["quantity"]
        if("interfaces" not in d):
            ifs = None
        else:
            ifs = parse_list(d,"interfaces")
            
        if(ifs is not None and len(ifs) != q):
            Tinker.value_error_map("quantity", str(q), str(len(ifs)),
                               Tinker.tostr_dict(d))
        elif(ifs is None
             or set(ifs) & set(d.keys()) == set()):
            pass
        elif((set(ifs) < set(d.keys()))):
            for i in ifs:
                d[i].validate(d[i])
        else:
            sys.exit("Error! interfaces cannot be partially enumerated subset")


    @classmethod
    def check_roles(cls, d):
        cls.check_interfaces(d)
        ifs = d["interfaces"]
        pid = None
        inds = []
        for i in ifs:
            r = d[i]["role"]
            if(r == "primary" and pid != None):
                sys.exit("Error! Two primary interfaces \"%s\" and \"%s\" found."
                         % (pid, i))
            elif(r == "primary"):
                pid = i
            elif(r == "independent"):
                inds.append(i)

        for i in inds:
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
        self.__fill(d)
        self.validate(d)
        pass

    def __fill(self, d):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        pass

    def verify(self, d):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        pass
    

