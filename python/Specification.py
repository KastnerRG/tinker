import json
import xml.etree.ElementTree as ET
from collections import defaultdict
import Memory
import Board
import Tinker 


class Specification(ET.Element):
    def __init__(self, f):
        super(Specification, self).__init__("Specification")
        fp = open(f, "r")
        self.info=defaultdict()
        self.__parse_info(fp)

    def __parse_info(self, fp):
        self.info = json.load(fp)

    def build(self, board):
        bi = board.get_info()
        si = self.info
        print ("Building BSP %s for board %s, version %s" %
               (si["Name"], bi["name"],bi["version"]))

    def get_info(self):
        return self.info
