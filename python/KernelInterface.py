import xml.etree.ElementTree as ET
import Tinker
import sys
from Interface import *
class KernelInterface(Interface):
    _C_INTERFACE_KEYS = set(["type"])
    def __init__(self, desc):
        """Construct a generic Interface Object

        Arguments:

        desc -- a dictionary object containing a description of this
        interface

        """
        super(KernelInterface,self).__init__(desc)

    @classmethod
    def parse(cls, desc):
        """
        
        Parse the description of this IP object from an dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        d = super(KernelInterface,cls).parse(desc)
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
        
    def implement(self, b):
        """

        Implement the Interface described by this object using the Board
        object describing the IP available on this board. 

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
                
    def __configure(self):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """

    def __get_cra_interface(self, version, verbose):
        e = ET.Element("interface",attrib={"name":"tinker", "port":"kernel_cra",
                                           "type":"master", "width":"64",
                                           "misc":"0"})
        return e

    def __get_irq_interface(self, version, verbose):
        e = ET.Element("interface",attrib={"name":"tinker", "port":"kernel_irq",
                                           "type":"irq", "width":"1"})
        return e
        
    def __get_clk_interface(self, version, verbose):
        e = ET.Element("kernel_clk_reset",
                       attrib={"clk":"tinker.kernel_clk",
                               "clk_2x":"tinker.kernel_clk2x",
                               "reset":"tinker.kernel_reset"})
        return e
        
    def get_interface_elements(self, version, verbose):
        l = []
        # TODO: Could do name of kernel clk pin
        l.append(self.__get_clk_interface(version, verbose))
        l.append(self.__get_irq_interface(version, verbose))
        l.append(self.__get_cra_interface(version, verbose))
        return l
        
    def get_host_elements(self, version, verbose):
        e = ET.Element("kernel_config", attrib={"size":"0x0100000", "start":"0x0"})
        return [e]
