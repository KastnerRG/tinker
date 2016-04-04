import xml.etree.ElementTree as ET
from collections import defaultdict, Counter
import Tinker

class IP(object):
    def __init__(self, e):
        self.info = defaultdict()
        ctr = Counter()
        ctr["alms"] = int(e.get("alms"))
        ctr["ffs"] = int(e.get("ffs"))
        ctr["dsps"] = int(e.get("dsps"))
        ctr["rams"] = int(e.get("rams"))
        self.info["resources"] = ctr
        
