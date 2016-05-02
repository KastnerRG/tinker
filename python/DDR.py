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
# Filename: DDR.py
# Version: 0.1 
# Description: Object that defines a DDR Memory Instance/Interface in a Board
# architecture
# Author: Dustin Richmond

import Tinker, Phy

class DDR(Phy.Phy):
    def __init__(self, e, enum):
        self.t = "DDR"
        super(DDR,self).__init__(e, "DDR", enum)
        info = self.__parse_info(e,self.t,self.info["id"])
        self.info.update(info)
        
    def __parse_info(self, e, t, id):
        d = {}
        d["clock_ratio"] = 2
        d["type"] = "DDR"
        fmax_mhz = e.get("fmax_mhz")
        if(not Tinker.is_number(fmax_mhz)):
            print (("ERROR: Maximum Frequency of type %s, is %s was %s, which is not a number.\n" +
                        "Check the board-specific XML file") %
                        (t, id, str(fmax)))
            exit(1)
        fmax_mhz = int(fmax_mhz)
        d["fmax_mhz"] = fmax_mhz

        bp = e.get("bank_pins")
        if(not Tinker.is_number(bp)):
            print ("ERROR: bank_pins of type %s id %s is not a number: %s:" %
                   (self.t, id, bp))
            exit(1)
        bp = int(bp)
        d["bank_pins"] = bp

        cp = e.get("column_pins");
        if(not Tinker.is_number(cp)):
            print ("ERROR: column_pins of type %s id %s is not a number: %s:" %
                   (self.t, id, cp))
            exit(1)
        cp = int(cp)
        d["column_pins"] = cp

        rp = e.get("row_pins")
        if(not Tinker.is_number(rp)):
            print ("ERROR: row_pins of type %s id %s is not a number: %s:" %
                   (self.t, id, rp))
            exit(1)
        rp = int(rp)
        d["row_pins"] = rp

        dqp = int(e.get("dq_pins"))
        if(not Tinker.is_number(dqp)):
            print ("ERROR: dq_pins of type %s id %s is not a number: %s:" %
                   (self.t, id, dqp))
            exit(1)
        dqp = int(dqp)
        d["dq_pins"] = dqp

        d["oct_pin"] = e.get("oct_pin");

        dqp2 = 2 ** Tinker.clog2(dqp)
        d["pow2_dq_pins"] = dqp2
        
        size = dqp2/8 * (2**bp) * (2 ** cp) * (2 ** rp)
        d["size"] = size

        d["bandwidth_bs"] = fmax_mhz * 10**6 * 2 * dqp2 / 8
        #print d["bandwidth_bs"]/(1000000)
        # TODO: Is bandwidth in bytes or megabytes / sec
        
        return d

    def print_info(self,l):
        super(DDR,self).print_info(l)
        print (l + 1)*"\t" + "Bandwidth: %d Bytes/Sec" % self.info["bandwidth_bs"]

    def build_spec(self, spec, n , id, base, burst, width, specification=False):
        r = super(DDR,self).build_spec(spec,n,id,base, burst,width, specification=specification)
        r.set("port","kernel_%s_if_%s_rw" % (n,id))
        r.set("latency","240") # Standard, recommended by Altera
        return r

