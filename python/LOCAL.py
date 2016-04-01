from Phy import Phy
import Tinker

class LOCAL(Phy):
    def __init__(self, e, enum):
        self.t = "LOCAL"
        super(LOCAL,self).__init__(e, "LOCAL", enum)
        info = self.__parse_info(e,self.t,self.info["id"])
        self.info.update(info)
    def __parse_info(self, e, t, id):
        d = {}
        return d
                                           
    def set_params(self):
        pass

