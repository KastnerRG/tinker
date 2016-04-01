import xml.etree.ElementTree as ET
from collections import defaultdict
import DDR
import LOCAL
import QDR
import Phy

class Memory(ET.Element):
    def __init__(self, xml):
        super(Memory, self).__init__("memory")
        self.ifs = []
        self.info = self.parse_info(xml) 

    def get_info(self):
        return self.info;

    def print_info(self,l):
        print "Showing info for memory type %s:" % self.info["type"]
        if(self.info["division"] != "continuous"):
            print l*"\t" + "Number of Interfaces: %d" % int(self.info["quantity"])
        for i in self.ifs:
            i.print_info(l)

    def parse_info(self,r):
        d = defaultdict();
        t = r.get("type")
        d["type"] = t
        d["enumeration"] = r.get("enum")
        d["division"] = r.get("division")
        # TODO: List diff for enum
        if(d["division"] == "discrete"):
            d["quantity"] = r.get("quantity")
        else:
            d["quantity"] = "\"infinite\""
        d["ids"] = []
        for e in r.findall("./[@type='%s']/*" % t):
            mem = Phy.initialize(t, e, d["enumeration"])
            self.ifs.append(mem)
            di = mem.get_info()
            d[di["id"]] = di
            d["ids"].append(di["id"])
        return d
        
    def add_system(self, memory_name, max_bandwidth, interleaved_bytes, config_addr, num_memories, mem_constr, system_constr, sys_idx, base_addr, more_args, sys_type, quantity, mem_frequency_mhz, ref_frequency_mhz, ratio, role, sys_width, addr_width,**mem_args):
        self.append(system_constr(memory_name, max_bandwidth, interleaved_bytes, config_addr, num_memories, mem_constr, sys_idx, base_addr, more_args, sys_type, quantity, mem_frequency_mhz, ref_frequency_mhz, ratio, role, sys_width, addr_width, **mem_args))


    def write(self, filename, pretty):
        # Add remaining elements of xml file
        host = ET.Element('host')
        kernel_config = ET.SubElement(host, 'kernel_config')
        kernel_config.set('start', '0x00000000')
        kernel_config.set('size', '0x0100000')
        self.append(host)
        interfaces = ET.Element('interfaces')
        interface = ET.SubElement(interfaces, 'interface')
        interface.set('name', 'acl_iface')
        interface.set('port', 'kernel_cra')
        interface.set('type', 'master')
        interface.set('width', '64')
        interface.set('misc', '0')
        interface = ET.SubElement(interfaces, 'interface')
        interface.set('name', 'acl_iface')
        interface.set('port', 'kernel_irq')
        interface.set('type', 'irq')
        interface.set('width', '1')
        interface = ET.SubElement(interfaces, 'interface')
        interface.set('name', 'acl_iface')
        interface.set('port', 'acl_internal_snoop')
        interface.set('type', 'streamsource')
        interface.set('enable', 'SNOOPENABLE')
        interface.set('width', '32')
        interface.set('clock', 'acl_iface.kernel_clk')
        kernel_clk_reset = ET.SubElement(interfaces, 'kernel_clk_reset')
        kernel_clk_reset.set('clk', 'acl_iface.kernel_clk')
        kernel_clk_reset.set('clk2x', 'acl_iface.kernel_clk2x')
        kernel_clk_reset.set('reset', 'acl_iface.kernel_reset')
        self.append(interfaces)
        
        bsf = open(filename, "w")
        bsf.write(pretty(self))
        bsf.close()
