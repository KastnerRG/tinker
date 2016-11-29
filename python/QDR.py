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
# Filename: QDR.py
# Version: 0.1 
# Description: Object that defines a QDR Memory Instance/Interface in a Board
# architecture
# Author: Dustin Richmond
import Tinker, Phy
import xml.etree.ElementTree as ET
class QDR(Phy.Phy):
    _C_BURST_WIDTHS = range(1,5)
    _C_BURST_DEFAULT = 1
    _C_CLOCK_RATIOS = ["Half", "Quarter", "Full"]
    _C_RATE = 2 # Double Data Rate (Not Quad. Thanks, Marketing)
    def __init__(self, e):
        super(QDR,self).__init__(e)

    @classmethod
    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this IP

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        Phy.check_size(d["size"])
        return

    def parse(self,e):
        """
        Parse the description of this IP object from an element tree
        element and return a defaultdictionary with the parameters
        found.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        d = super(QDR,self).parse(e)
        pow2_dq_pins = d["pow2_dq_pins"]

        address_pins = Tinker.parse_int(e, "address_pins", ET.tostring)
        burst = Tinker.parse_int(e, "burst", ET.tostring)

        size = pow2_dq_pins/8 * (2**address_pins) * burst
        d["size"] = int(size)

        self.validate(d)
        return d
    
    def get_interface(self, sid, verbose=False):
        r = super(QDR,self).get_interface(verbose=specification)
        i.set("latency","150") # Standard, recommended by Altera
        r_attrib = {"name": "kernel_%s_if_%s_r" % (sid,id),
                    "direction":"r"}
        ET.SubElement(i,"port",attrib=r_attrib)
        w_attrib = {"name": "kernel_%s_if_%s_w" % (sid,id),
                    "direction":"w"}
        ET.SubElement(i,"port",attrib=w_attrib)
        return i

