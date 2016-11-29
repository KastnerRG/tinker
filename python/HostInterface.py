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
import abc, sys
import Interface
class HostInterface(Interface.Interface):
    def __init__(self, d):
        """Construct a generic Interface Object

        Arguments:

        d -- a dictionary describing the attributes of the interface

        """
        super(MemoryGroup,self).__init__(d)
        d = self.parse(d)
        self.validate(d)
        self.update(d)

    def parse(cls, e):
        """
        
        Parse the description of this IP object from an dictionary
        return a defaultdictionary built from the key-value pairs.

        Arguments:

        e -- An element tree element containing the description of this
        object
        
        """
        pass

    def validate(cls, d):
        """

        Validate the parameters that describe the intrinsic settings of
        this Interface

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        pass

    def implement(self, b):
        """

        Implement the Interface described by this object using the Board
        object describing the IP available on this board. 

        Arguments:

        d -- A Description object, containing the parsed user description
        of a custom board
        
        """
        self.__fill(d)
        self.validate(d)
        pass

    def __fill(self, d):
        """

        Fill in any missing defaults in a high level description used to
        configure this object

        Arguments:

        d -- A Description object, containing the possibly incomplete
        parsed user description of a custom board
        
        """
        pass

    def verify(self, d):
        """

        Verify that this object can implement the high level description


        Arguments:

        d -- A Description object, containing the complete description
        of a the IP configuration
        
        """
        pass
