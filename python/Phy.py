import xml.etree.ElementTree as ET
from collections import defaultdict
import Tinker
class Phy(ET.Element):
    def __init__(self, e, t, enum):
        self.t = t;
        self.info = self.__parse_info(e, t, enum)
        self.params = self.__parse_params(e)
        super(Phy,self).__init__("interface")

    def __parse_info(self, e, t, enum):
        d = defaultdict()
        id = e.get("id")
        d["id"] = id
        if(not Tinker.match_enum(id,enum)):
            print (("ERROR: Enumeration of type %s was %s but ID is %s.\n" +
                        "Check the board-specific XML file") %
                        (t, enum, id))
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
            if(not Tinker.match_enum(p,enum)):
                print (("ERROR: Enumeration of type %s was %s but partner of %s is %s.\n" +
                    "Check the board-specific XML file") %
                    (t, enum, id, p))
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
        err = Tinker.list_diff(ratios,["quarter","half","full"])
        if(len(err) > 0):
            print (("ERROR: Unknown ratio type(s) for %s, id %s in XML file: %s" +
                    "Check the board-specific XML file") %
                    (t, id,str(err)))
            exit(1)
        d["ratios"] = ratios

        rate = [s.strip() for s in e.get("rate").split(",")]
        err = Tinker.list_diff(rate,["single","double"])
        if(len(err) > 0):
            print (("ERROR: Unknown rate for %s, id %s in XML file: %s\n" +
                    "Check the board-specific XML file") %
                    (t, id,str(err)))
            exit(1)
        d["rate"] = rate

        fmax_mhz = e.get("fmax_mhz")
        if(not Tinker.is_number(fmax_mhz)):
            print (("ERROR: Maximum Frequency of type %s, is %s was %s, which is not a number.\n" +
                        "Check the board-specific XML file") %
                        (t, id, str(fmax)))
            exit(1)
        d["fmax_mhz"] = int(fmax_mhz)

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
        print (l + 1)*"\t" + "Bandwidth: %d Bytes/Sec" % (self.info["fmax_mhz"] * 10**6 * self.info["pow2_dq_pins"])
        print (l + 1)*"\t" + "Associated Interfaces: %s" % str(self.info["group"])
        print (l + 1)*"\t" + "Roles: %s " % str(self.info["roles"])
        print (l + 1)*"\t" + "Ports: %s " % str(self.info["ports"])

    def set_params(self):
        pass

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
                                           
