import xml.etree.ElementTree as ET
from collections import defaultdict
import DDR
import LOCAL
import QDR
import Phy
from IP import IP
import math

class Memory(IP):
    def __init__(self, xml):
        super(Memory, self).__init__(xml)
        self.ifs = {}
        info = self.parse_info(xml) 
        self.info.update(info)
        self.spec_keys = {"name": max}
        self.specification_keys = {}
        
    def get_info(self):
        return self.info;

    def print_info(self,l):
        print "Showing info for memory type %s:" % self.info["type"]
        if(self.info["division"] != "continuous"):
            print l*"\t" + "Number of Interfaces: %d" % int(self.info["quantity"])
        for k,i in self.ifs.iteritems():
            i.print_info(l)

    def parse_info(self,r):
        d = defaultdict();
        t = r.get("type")
        d["type"] = t
        d["enumeration"] = r.get("enum")
        d["division"] = r.get("division")
        d["burst"] = r.get("burst") # TODO
        # TODO: List diff for enum
        if(d["division"] == "discrete"):
            d["quantity"] = r.get("quantity")
        else:
            d["quantity"] = "\"infinite\""
        d["ids"] = []
        for e in r.findall("./[@type='%s']/*" % t):
            mem = Phy.initialize(t, e, d["enumeration"])
            di = mem.get_info()
            d[di["id"]] = di
            d["ids"].append(di["id"])
            self.ifs[di["id"]] = mem
        return d

    def build_spec(self,spec, n, base, specification=False):
        s = spec.get_info()
        r = ET.Element("global_mem", attrib={"name": self.info["type"] + "_" + str(n)})
        burst = s.get("Burst","16")
        width = int(s[n]["Width"])
        intbytes = int(burst) * width / 8
        r.set("interleaved_bytes", str(intbytes))
        if(n == "0"):
            r.set("config_addr", "0x018")
            r.set("default","1")
        else:
            r.set("config_addr", hex(int("0x100",16) + (int(n)-1) * int("0x18",16)))

        size = 0
        bandwidth = 0
        for id in s[n]["Interfaces"]:
            bandwidth += self.info[id]["bandwidth_bs"]
            i = self.ifs[id]
            e = i.build_spec(spec,n,id,base+size,burst,width,specification=specification)
            size += int(s[n][id]["Size"],16)
            r.append(e);

        r.set("max_bandwidth", str(int(bandwidth)/1000000))
        if(specification):
            r.set("base_address",hex(base))
            r.set("quantity",str(len(s[n]["Interfaces"])))
            r.set("width",str(width))
            r.set("sys_id",str(n))
            r.set("type",s[n]["Type"])
            r.set("maxburst",str(burst))
            r.set("addr_width",str(int(math.log(size,2))))
            r.set("role",s[n]["Role"])
        return r

    def gen_macros(self, spec, n):
        s = spec.get_info()
        macros =""
        for intf in s[n]["Interfaces"]:
            i = self.ifs[intf]
            macros += i.gen_macros(spec, n)
        return macros

