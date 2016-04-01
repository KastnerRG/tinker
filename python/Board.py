import xml.etree.ElementTree as ET
from collections import defaultdict
import Memory
import Tinker 

class Board(ET.Element):
    def __init__(self, xml, version, name):
        super(Board, self).__init__("board")
        self.set("version", version)
        self.set("name", name)
        self.types = []
        self.info = self.parse_info(ET.parse(xml)) 

    def get_info(self):
        return self.info;

    def print_info(self,l):
        print l*"\t" + "Available Memories: " + str(self.info["types"])
        for t in self.types:
            t.print_info(l + 1)
        
    def parse_info(self,xml):
        d = defaultdict();
        r = xml.getroot()
        d["version"] = r.get("version")
        n = r.get("name")
        d["types"] = []
        for e in r.findall("./memory/[@type]"):
            mem = Memory.Memory(e);
            self.types.append(mem)
            dm = mem.get_info()
            d[dm["type"]] = dm
            d["types"].append(dm["type"])
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
