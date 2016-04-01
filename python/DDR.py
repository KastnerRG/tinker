from Phy import Phy
import Tinker

class DDR(Phy):
    def __init__(self, e, enum):
        self.t = "DDR"
        super(DDR,self).__init__(e, "DDR", enum)
        info = self.__parse_info(e,self.t,self.info["id"])
        self.info.update(info)
        
    def __parse_info(self, e, t, id):
        d = {}

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
        return d

    def set_params(self):
        pass
