from qgis.core import (QgsApplication)
from pathlib import Path


class QgisSetup:

    def __init__(self):
        self.qgs = QgsApplication([], False)
        self.qgs.initQgis()

    def exit(self):
        self.qgs.exit()

    # def setup(self, config):

    # qgis_path = config['qgis_path']
    # if qgis_path == None:
    #     print('QGIS location not given')
    #     return False
    # if not (Path(qgis_path).exists()):
    #     print('QGIS file not found')
    #     return False
    # QgsApplication.setPrefixPath(qgis_path, True)
    # self.qgs = QgsApplication([], False)
    # self.qgs.initQgis()
    # return self.qgs
