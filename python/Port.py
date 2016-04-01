import xml.etree.ElementTree as ET

class Port(ET.Element):
    # <global_mem name="DDR" max_bandwidth="25600" interleaved_bytes="1024" config_addr="0x018">
    def __init__(self, name, direction):
        super(Port,self).__init__("port")
        self.set("name",name)
        self.set("direction",direction)
