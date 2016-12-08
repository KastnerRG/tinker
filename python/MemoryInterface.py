import DDR, QDR
import Interface, Tinker
import sys
from Interface import *
class MemoryInterface(Interface):
    _C_INTERFACE_KEYS = set(["role","master", "burst", "ratio"])
    _C_INTERFACE_TYPES = ["DDR3","QDRII"]
    _C_INTERFACE_ROLES = ["primary", "secondary", "independent"]
    def __init__(self, desc):
        """Construct a generic Interface Object

        Arguments:

        desc -- a dictionary object containing a description of this
        interface

        """
        super(MemoryInterface,self).__init__(desc)
        
    @classmethod
    def parse(cls, desc):
        """
        
        Parse the description of this IP object from an dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        d = dict()
        cls.parse_keys(desc)
        d["role"] = cls.parse_role(desc)
        if("master" in desc):
            d["master"] = cls.parse_master(desc)
        return d

    @classmethod
    def parse_master(cls, d):
        return parse_string(d, "master")

    @classmethod
    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this Interface

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        cls.check_role(d)
        if(d["role"] == "independent"
           and "master" not in d):
            Tinker.key_error("master", str(d))
        else:
            return
            cls.check_master(d)
        
    def implement(self, b):
        """

        Implement the Interface described by this object using the Board
        object describing the IP available on this board. 

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        self.validate(self)
        b.configure(self)
        self["IP"] = b

    def __configure(self):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        pass

    def verify(self):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        self["IP"].verify()
        pass
    

