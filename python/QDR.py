from Phy import Phy
import Tinker

class QDR(Phy):
    def __init__(self, e, enum):
        self.t = "QDR"
        super(QDR,self).__init__(e, "QDR", enum)
        info = self.__parse_info(e,self.t,self.info["id"])
        self.info.update(info)

    def __parse_info(self, e, t, id):
        d = {}

        ap = e.get("address_pins");
        if(not Tinker.is_number(ap)):
            print ("ERROR: address_pins of type %s id %s is not a number: %s:" %
                   (self.t, id, ap))
            exit(1)
        ap = int(ap)
        d["addess_pins"] = ap
        
        dqp = e.get("dq_pins");
        if(not Tinker.is_number(dqp)):
            print ("ERROR: dq_pins of type %s id %s is not a number: %s:" %
                   (self.t, id, dqp))
            exit(1)
        dqp = int(dqp)
        d["dq_pins"] = dqp

        b = e.get("burst");
        if(not Tinker.is_number(b)):
            print ("ERROR: burst of type %s id %s is not a number: %s:" %
                   (self.t, id, b))
            exit(1)
        b = int(b)
        d["burst"] = int(b)

        d["oct_pin"] = e.get("oct_pin");

        dqp2 = 2 ** Tinker.clog2(dqp)
        d["pow2_dq_pins"] = dqp2

        size = dqp2/8 * (2**ap) * b
        d["size"] = size

        return d

    def set_params(self):
        pass
