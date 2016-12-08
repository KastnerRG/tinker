# ----------------------------------------------------------------------
# Copyright (c) 2016, The Regents of the University of California All
# rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#
#     * Neither the name of The Regents of the University of California
#       nor the names of its contributors may be used to endorse or
#       promote products derived from this software without specific
#       prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL REGENTS OF THE
# UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
# ----------------------------------------------------------------------
# Filename: Specification.py
# Version: 0.1 
# Description: An object encapsulating the specification files board_spec.xml,
# which is used by Altera's OpenCL SDK, and board_specification.xml, which is
# used by Tinker's TCL Scripts
# Author: Dustin Richmond

import xml.etree.ElementTree as ET
import Board, Description
from Tinker import check_path, prettify

class Specification(ET.ElementTree):
    __C_FILENAME_MAP = {True: "board_specification.xml",
                        False: "board_spec.xml"}
    # TODO: Do we pass the name in here? Or get it from Tinker using b & d
    def __init__(self, t, b, d, verbose):
        """Construct a Specification Object

        Arguments:

        t -- A Tinker object with parameters for board generation

        d -- A Description object that describes the user
        settings of a custom board

        b -- A Board object that describes the interfaces and
        custom IP on a development board
        
        """
        self.__t = t
        self.__b = b
        self.__d = d
        self.__version = t.get_version()
        self.__verbose = verbose

        r = self.__get_root()
        
        e = self.__b.get_compile_element()
        r.append(e)
        
        e = self.__get_device_element()
        r.append(e)

        ms = self.__d.get_global_mem_elements(self.__version, self.__verbose)
        r.extend(ms)

        e = self.__get_interfaces_element()
        r.append(e)

        e = self.__get_host_element()
        r.append(e)

        self.__filename = self.__C_FILENAME_MAP[self.__verbose]

        super(Specification,self).__init__(element=r)
        
    def __get_root(self):
        n = self.__t.get_name(self.__b, self.__d)
        if(self.__version == 14.1):
            r = ET.Element("board", attrib={"version": "0.9","name":n})
        else:
            r = ET.Element("board", attrib={"version": str(self.__version),
                                            "name":n})
        if(self.__verbose):
            r.set("file", self.__t.get_name_skel_xml())
        return r
                
    def __get_device_element(self):
        e = ET.Element("device", attrib={"device_model":self.__b["model"]})
        
        ur = ET.Element("used_resources")
        
        e.append(ur)
        r = self.__d.get_resources(self.__version, self.__verbose)
        for rt,rc in r.iteritems():
            re = ET.Element(rt, attrib={"num":str(rc)})
            ur.append(re)
            
        return e

    def __get_interfaces_element(self):
        v = self.__t.get_version()
        e = ET.Element("interfaces")
        ifs = self.__d.get_interface_elements(self.__version, self.__verbose)
        for i in ifs:
            e.append(i)
        return e
            
    def __get_host_element(self):
        e = ET.Element("host")
        hes = self.__d.get_host_elements(self.__version, self.__verbose)
        for he in hes:
            e.append(he)
        return e

    def write(self, p):
        """Write an XML representation of this Specification object
        to a file.
        
        Arguments:
        
        p - file destination path
        
        """
        check_path(p)
        p += "/"+self.__filename
        s = prettify(self.getroot())
        fp = open(p, "w")
        fp.write(s)
        fp.close()
