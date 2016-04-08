import xml.etree.ElementTree as ET
from collections import defaultdict, Counter
import Memory
import Tinker
import math

class Board(ET.Element):
    def __init__(self, xml, version, name):
        super(Board, self).__init__("board")
        self.set("version", version)
        self.set("name", name)
        self.types = {}
        self.info = self.parse_info(ET.parse(xml)) 

    def get_info(self):
        return self.info;

    def print_info(self,l):
        print l*"\t" + "Available Memories: " + str(self.info["types"])
        for t,obj in self.types.iteritems():
            obj.print_info(l + 1)
        
    def parse_info(self,xml):
        d = defaultdict();
        r = xml.getroot()
        d["version"] = r.get("version")
        n = r.get("name")
        d["name"] = n
        d["types"] = []
        d["model"] = r.get("model")

        for e in r.findall("./memory/[@type]"):
            mem = Memory.Memory(e);
            dm = mem.get_info()
            d[dm["type"]] = dm
            d["types"].append(dm["type"])
            self.types[dm["type"]] = mem
                        
        return d

    def build_spec(self, spec, version, specification=False, xmlfn = ""):
        s = spec.get_info()
        r = ET.Element("board", attrib={"version": version, "name":s["Name"]})
        if(specification):
            r.set("file", xmlfn)

        base = 0
        size_default = 0
        for sys in s["Systems"]:
            t = s[sys]["Type"]
            m = self.types[t]
            e = m.build_spec(spec,sys,base,specification=specification)
            r.append(e)
            for i in s[sys]["Interfaces"]:
                base += int(s[sys][i]["Size"],16)
                if(sys == "0"):
                    size_default += int(s[sys][i]["Size"],16)

        # Summary of Resources
        resources = Counter({"alms":0,
                             "ffs":0,
                             "rams":0,
                             "dsps":0})
        for sys in s["Systems"]:
            t = s[sys]["Type"]
            resources.update(self.info[t]["resources"])

            for i in s[sys]["Interfaces"]:
                resources.update(self.info[t][i]["resources"])
        deve = ET.SubElement(r,"device", attrib={"device_model":self.info["model"]})
        re = ET.SubElement(deve,"used_resources")
        for rt,num in resources.iteritems():
            ET.SubElement(re, rt, attrib={"num":str(num)})

        # Host Interface
        host = ET.SubElement(r,"host")
        ET.SubElement(host,"kernel_config",
                      attrib={"start":"0x00000000","size":"0x0100000"})
        
        # ACL Plumbing
        intfs = ET.SubElement(r, "interfaces")
        # TODO: board, not acl_iface
        kernel_cra = ET.SubElement(intfs,"interface",
                                   attrib={"name":"tinker",
                                            "port":"kernel_cra",
                                            "type":"master",
                                            "width":"64",
                                            "misc":"0"}) # Purpose of misc?

        kernel_irq = ET.SubElement(intfs,"interface",
                                   attrib={"name":"tinker",
                                           "port":"kernel_irq",
                                           "type":"irq",
                                           "width":"q"})
        snoop = ET.SubElement(intfs,"interface",
                              attrib={"name":"tinker",
                                      "port":"acl_internal_snoop",
                                      "type":"streamsource",
                                      "enable":"SNOOPENABLE",
                                      "clock":"tinker.kernel_clk",
                                      "width":str(int(math.log(size_default)/math.log(2)))})
        kclk_rst = ET.SubElement(intfs,"kernel_clk_reset",
                                 attrib={"clk":"tinker.kernel_clk",
                                         "clk2x":"tinker.kernel_clk2x",
                                         "reset":"tinker.kernel_reset"})


        return r



    def edit_system(self, spec, sysxml):
        sysroot = ET.parse(sysxml).getroot()
        s = spec.get_info()
        for sys in s["Systems"]:
            t = s[sys]["Type"]
            for i in s[sys]["Interfaces"]:
                n = t.lower()+ "_" + i
                r = s[sys][i]["Role"]
                ET.SubElement(sysroot,"interface",
                              attrib={"name":n,
                                      "internal":"tinker."+n,
                                      "type":"conduit",
                                      "dir":"end"})
                if(r == "primary"):
                    ET.SubElement(sysroot,"interface",
                                  attrib={"name":n,
                                          "internal":"tinker."+n+"_mem_oct",
                                          "type":"conduit",
                                          "dir":"end"})
                if(r == "primary" or r == "independent"):
                    ET.SubElement(sysroot,"interface",
                                  attrib={"name":n,
                                          "internal":"tinker."+n+"_pll_ref",
                                          "type":"conduit",
                                          "dir":"end"})
                
        print Tinker.prettify(sysroot)
