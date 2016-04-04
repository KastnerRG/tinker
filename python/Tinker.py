import xml.etree.ElementTree as et
from xml.dom import minidom
import math
def is_number(n):
    try:
        float(n)
        return True
    except ValueError:
        return False            

def is_alphachar(s):
    return s.isalpha() and len(s) == 1

def match_enum(id, enum):
    return ((is_alphachar(id) and enum == "alphabetical") or
        (is_number(id) and enum == "numerical"))

def list_diff(l,cl):
    return list(set(l) - set(cl))

def prettify(elem):
    rough_string = et.tostring(elem, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")

def clog2(i):
    return math.floor(math.log(i)/math.log(2))

def rate2int(ratio):
    if(ratio == "single"):
        return 1
    elif(ratio == "double"):
        return 2

def ratio2float(ratio):
    if(ratio =="Full"):
        return 1
    if(ratio =="Half"):
        return .5
    if(ratio =="Quarter"):
        return .25
